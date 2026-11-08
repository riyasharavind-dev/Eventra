import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eventor_vendor/models/vendor_tour_step.dart';
import 'package:eventor_vendor/repositories/onboarding_repository.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late OnboardingRepository repository;
  late Future<void> Function(HttpRequest) respond;
  Future<void> session(String uid) => client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'test-token',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'user': {
        'id': uid,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
  Future<void> reply(
    HttpRequest request,
    Object body, [
    int status = 200,
  ]) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async => respond(request));
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = OnboardingRepository(client: client);
    await session('vendor-one');
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  test('offline progress syncs on the next successful load using an explicit account ID', () async {
    var offline = true;
    var state = const VendorGuideProgress();
    respond = (request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['p_account_id'], 'vendor-one');
      if (offline) {
        await reply(request, {
          'code': 'XX000',
          'message': 'Offline simulation',
        }, 400);
        return;
      }
      if (request.uri.path.endsWith('save_vendor_guide_progress')) {
        state = VendorGuideProgress(
          status: body['p_status'] as String,
          step: body['p_step'] as int,
        );
      }
      await reply(request, state.toMap());
    };
    expect(
      await repository.saveProgress(
        const VendorGuideProgress(status: 'in_progress', step: 4),
      ),
      isFalse,
    );
    final local = await repository.loadProgress();
    expect(local.step, 4);
    expect(local.synced, isFalse);
    offline = false;
    final remote = await repository.loadProgress();
    expect(remote.step, 4);
    expect(remote.synced, isTrue);
  });
  test(
    'switching accounts never reuses the other vendor local guide progress',
    () async {
      respond = (request) => reply(request, {
        'code': 'XX000',
        'message': 'Offline simulation',
      }, 400);
      await repository.saveProgress(
        const VendorGuideProgress(status: 'completed', step: 6),
      );
      expect((await repository.loadProgress()).status, 'completed');
      await session('vendor-two');
      await expectLater(
        repository.loadProgress(),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
  test('late sync response cannot overwrite newer local progress', () async {
    final arrived = Completer<void>(), release = Completer<void>();
    respond = (request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      if (body['p_step'] == 1) {
        arrived.complete();
        await release.future;
      }
      await reply(request, {
        'status': 'in_progress',
        'last_step': body['p_step'] ?? 4,
        'guide_version': 1,
      });
    };
    final first = repository.saveProgress(
      const VendorGuideProgress(status: 'in_progress', step: 1),
    );
    await arrived.future;
    await repository.saveProgress(
      const VendorGuideProgress(status: 'in_progress', step: 4),
    );
    release.complete();
    await first;
    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString('vendor_guide_v1_vendor-one')!) as Map;
    expect(saved['last_step'], 4);
    expect(saved['dirty'], isFalse);
  });
}
