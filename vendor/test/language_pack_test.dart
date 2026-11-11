import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eventor_vendor/models/app_language_pack.dart';
import 'package:eventor_vendor/repositories/language_pack_repository.dart';
import 'package:eventor_vendor/services/vendor_localization.dart';
import 'package:eventor_vendor/l10n/vendor_strings.dart';

AppLanguagePack pack({
  String code = 'ta',
  int version = 1,
  String direction = 'ltr',
  Map<String, String>? messages,
}) {
  final content = jsonEncode({
    'schema': 1,
    'app': 'vendor',
    'code': code,
    'version': version,
    'direction': direction,
    'messages':
        messages ?? {'common.booking_count.other': '{count} முன்பதிவுகள்'},
  });
  final checksum = sha256.convert(utf8.encode(content)).toString();
  return AppLanguagePack.parse(
    {'content': content, 'sha256': checksum},
    AppLanguageOption(
      code: code,
      name: code,
      nativeName: code,
      version: version,
      checksum: checksum,
      direction: direction,
    ),
  );
}

class FakeRepository extends LanguagePackRepository {
  final Map<String, AppLanguagePack> packs = {};
  List<AppLanguageOption> available = [];
  int network = 0;
  bool offline = false;
  @override
  Future<List<AppLanguageOption>> cachedManifest() async => available;
  @override
  Future<AppLanguagePack?> cachedPack(String code) async => packs[code];
  @override
  Future<List<AppLanguageOption>> fetchManifest() async {
    network++;
    if (offline) throw StateError('offline');
    return available;
  }

  @override
  Future<AppLanguagePack> download(AppLanguageOption option) async {
    network++;
    if (offline) throw StateError('offline');
    return pack(code: option.code, version: option.version);
  }

  @override
  Future<void> storePack(
    AppLanguagePack value, {
    required String preserveCode,
  }) async {
    packs[value.option.code] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('offline startup and cached selection never request network', () async {
    final repo = FakeRepository()..offline = true;
    repo.packs['ta'] = pack();
    final localization = await VendorLocalization.loadLocal(
      'ta',
      repository: repo,
    );
    expect(localization.plural('common.booking_count', 3), '3 முன்பதிவுகள்');
    expect(await localization.prepare('ta'), isNotNull);
    expect(repo.network, 0);
    await localization.refresh(force: true);
    expect(localization.failed, true);
    expect(localization.plural('common.booking_count', 3), '3 முன்பதிவுகள்');
  });
  test(
    'new languages download completely before activation and update atomically',
    () async {
      final repo = FakeRepository();
      repo.available = [pack(code: 'hi', version: 2).option];
      final localization = VendorLocalization(
        code: 'en',
        repository: repo,
        options: repo.available,
      );
      final downloaded = await localization.prepare('hi');
      expect(localization.code, 'en');
      expect(repo.packs['hi']?.option.version, 2);
      localization.activate('hi', downloaded);
      repo.available = [pack(code: 'hi', version: 3).option];
      await localization.refresh(force: true);
      expect(repo.packs['hi']?.option.version, 3);
      expect(localization.code, 'hi');
    },
  );
  test('invalid checksum, identity and placeholders are rejected', () {
    final valid = pack();
    expect(
      () => AppLanguagePack.parse({
        ...valid.toCache(),
        'content': 'tampered',
      }, valid.option),
      throwsFormatException,
    );
    expect(
      () => AppLanguagePack.parse(
        valid.toCache(),
        const AppLanguageOption(
          code: 'hi',
          name: 'Hindi',
          nativeName: 'Hindi',
          version: 1,
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => pack(messages: {'common.booking_count.other': 'missing count'}),
      throwsFormatException,
    );
  });
  test('wrong-code and corrupt persisted caches safely fall back', () async {
    final repo = LanguagePackRepository();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      repo.key('ta'),
      jsonEncode(pack(code: 'hi').toCache()),
    );
    expect(await repo.cachedPack('ta'), isNull);
    await prefs.setString(repo.key('ta'), 'broken json');
    expect(await repo.cachedPack('ta'), isNull);
  });
  test('cache has bounded retention and preserves selected language', () async {
    final repo = LanguagePackRepository();
    for (final code in ['ta', 'hi', 'ml', 'te', 'kn', 'fr', 'de']) {
      await repo.storePack(pack(code: code), preserveCode: 'ta');
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(LanguagePackRepository.indexKey)!.length, 5);
    expect(await repo.cachedPack('ta'), isNotNull);
    expect(await repo.cachedPack('de'), isNotNull);
  });
  test('catalog has complete Tamil and identical placeholder contracts', () {
    final rows = jsonDecode(
      File('../admin/data/vendor_translation_catalog.json').readAsStringSync(),
    ) as List;
    expect(rows.length, vendorEnglishStrings.length);
    for (final row in rows) {
      expect((row['tamil'] as String).trim(), isNotEmpty, reason: row['key']);
      expect(
        messagePlaceholders(row['tamil']),
        messagePlaceholders(row['default_text']),
        reason: row['key'],
      );
      expect(vendorEnglishStrings[row['key']], row['default_text']);
    }
  });
  test(
    'the complete published Tamil catalog resolves source words offline',
    () async {
      final rows = jsonDecode(
        File('../admin/data/vendor_translation_catalog.json')
            .readAsStringSync(),
      ) as List;
      final translations = <String, String>{
        for (final row in rows) row['key'] as String: row['tamil'] as String,
      };
      final repo = FakeRepository()..offline = true;
      repo.packs['ta'] = pack(messages: translations);
      final localization = await VendorLocalization.loadLocal(
        'ta',
        repository: repo,
      );
      final row = rows.firstWhere((v) => v['default_text'] == 'Language');
      expect(localization.source('Language'), row['tamil']);
      expect(localization.plural('common.business_count', 2), '2 வணிகங்கள்');
      expect(repo.network, 0);
    },
  );
  test(
    'a failed new-language download keeps the active selection intact',
    () async {
      final repo = FakeRepository()..offline = true;
      final localization = VendorLocalization(
        code: 'en',
        repository: repo,
        options: [pack(code: 'hi').option],
      );
      await expectLater(localization.prepare('hi'), throwsStateError);
      expect(localization.code, 'en');
      expect(repo.packs, isEmpty);
    },
  );
  test('RTL and unknown framework locales retain safe rendering', () {
    final rtl = pack(code: 'ar', direction: 'rtl');
    final localization = VendorLocalization(code: 'en');
    localization.activate('ar', rtl);
    expect(localization.direction.name, 'rtl');
    localization.activate('zz', pack(code: 'zz'));
    expect(localization.frameworkLocale.languageCode, 'en');
    expect(localization.tr('unknown'), 'Text unavailable');
  });
}
