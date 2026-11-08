import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eventor_customer/repositories/auth_repository.dart';
import 'package:eventor_customer/utils/auth_error_message.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late AuthRepository repository;
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
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path.contains('/logout')) {
        request.response.statusCode = 204;
        await request.response.close();
        return;
      }
      await respond(request);
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = AuthRepository(client: client);
    await session('original-user');
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
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

  test(
    'identity validation sends fixed app role and keeps original UID',
    () async {
      respond = (request) async {
        expect(request.uri.path, '/rest/v1/rpc/get_my_app_account');
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body, {'p_app_role': 'customer'});
        await reply(request, {
          'user_id': 'original-user',
          'account_role': 'customer',
          'verified_phone': null,
          'phone_verified_at': null,
        });
      };
      final identity = await repository.getAccountIdentity();
      expect(identity.userId, 'original-user');
      expect(client.auth.currentUser?.id, 'original-user');
    },
  );
  test('wrong-role denial clears local session', () async {
    respond = (request) => reply(request, {
      'code': '42501',
      'message': 'Account permission required',
    }, 403);
    await expectLater(
      repository.validateAccountRole(),
      throwsA(isA<AccountAccessException>()),
    );
    expect(client.auth.currentSession, isNull);
  });
  test('unrelated database failure does not sign user out', () async {
    respond = (request) =>
        reply(request, {'code': 'XX000', 'message': 'Temporary failure'}, 400);
    await expectLater(
      repository.validateAccountRole(),
      throwsA(isA<PostgrestException>()),
    );
    expect(client.auth.currentUser?.id, 'original-user');
  });
  test(
    'stale denied response cannot sign out a newly switched account',
    () async {
      final arrived = Completer<void>();
      final release = Completer<void>();
      respond = (request) async {
        arrived.complete();
        await release.future;
        await reply(request, {'code': '42501', 'message': 'Denied'}, 403);
      };
      final attempt = repository.validateAccountRole();
      final assertion = expectLater(
        attempt,
        throwsA(isA<AccountAccessException>()),
      );
      await arrived.future;
      await session('new-user');
      release.complete();
      await assertion;
      expect(client.auth.currentUser?.id, 'new-user');
    },
  );
}
