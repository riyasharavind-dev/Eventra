import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show Intl;

import '../l10n/vendor_strings.dart';
import '../models/app_language_pack.dart';
import '../repositories/language_pack_repository.dart';
import 'app_live_data.dart';

class VendorLocalization extends ChangeNotifier {
  VendorLocalization({
    required this.code,
    LanguagePackRepository? repository,
    this._pack,
    List<AppLanguageOption>? options,
  }) : repository = repository ?? LanguagePackRepository(),
       _options = options ?? [AppLanguageOption.english];
  final LanguagePackRepository repository;
  String code;
  AppLanguagePack? _pack;
  List<AppLanguageOption> _options;
  bool refreshing = false, failed = false, _again = false, _disposed = false;
  DateTime? _lastSuccess;
  static final _sourceKeys = {
    for (final entry in vendorEnglishStrings.entries) entry.value: entry.key,
  };
  static final _patterns = vendorEnglishStrings.entries
      .where(
        (e) =>
            messagePlaceholders(e.value).isNotEmpty &&
            RegExp(r'[A-Za-z]')
                .hasMatch(e.value.replaceAll(RegExp(r'\{[^}]+\}'), '')),
      )
      .map((e) {
        final names = <String>[];
        var pattern = '';
        var cursor = 0;
        for (final match in RegExp(
          r'\{([A-Za-z][A-Za-z0-9_]*)\}',
        ).allMatches(e.value)) {
          pattern += RegExp.escape(e.value.substring(cursor, match.start));
          pattern += '(.*?)';
          names.add(match[1]!);
          cursor = match.end;
        }
        pattern += RegExp.escape(e.value.substring(cursor));
        return (
          key: e.key,
          regex: RegExp('^$pattern\$', dotAll: true),
          names: names,
        );
      })
      .toList();
  static Future<VendorLocalization> loadLocal(
    String code, {
    LanguagePackRepository? repository,
  }) async {
    final repo = repository ?? LanguagePackRepository();
    final options = await repo.cachedManifest();
    final pack = await repo.cachedPack(code);
    return VendorLocalization(
      code: code,
      repository: repo,
      pack: pack,
      options: options,
    );
  }

  List<AppLanguageOption> get options {
    final list = List<AppLanguageOption>.of(_options);
    if (!list.any((v) => v.code == 'en')) {
      list.insert(0, AppLanguageOption.english);
    }
    if (code != 'en' && !list.any((v) => v.code == code)) {
      list.add(
        _pack?.option ??
            AppLanguageOption(code: code, name: code, nativeName: code),
      );
    }
    return list;
  }

  AppLanguageOption get selected => options.firstWhere((v) => v.code == code);
  TextDirection get direction => (_pack?.direction ?? 'ltr') == 'rtl'
      ? TextDirection.rtl
      : TextDirection.ltr;
  Locale get frameworkLocale {
    final parts = code.split('-');
    final script = parts.skip(1).where((v) => v.length == 4).firstOrNull;
    final country = parts
        .skip(1)
        .where((v) => v.length == 2 || RegExp(r'^\d{3}$').hasMatch(v))
        .firstOrNull;
    final locale = Locale.fromSubtags(
      languageCode: parts.first,
      scriptCode: script,
      countryCode: country?.toUpperCase(),
    );
    return GlobalMaterialLocalizations.delegate.isSupported(locale)
        ? locale
        : const Locale('en');
  }

  List<Locale> get frameworkLocales => {
    const Locale('en'),
    frameworkLocale,
    ...options
        .map((o) => Locale(o.code.split('-').first))
        .where(GlobalMaterialLocalizations.delegate.isSupported),
  }.toList();
  String tr(String key, {Map<String, Object?> args = const {}}) {
    final fallback = vendorEnglishStrings[key] ?? 'Text unavailable';
    var value = _pack?.messages[key] ?? fallback;
    if (value.trim().isEmpty) value = fallback;
    return value.replaceAllMapped(
      RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}'),
      (m) => args[m[1]]?.toString() ?? '?',
    );
  }

  String plural(String key, num count, {Map<String, Object?> args = const {}}) {
    final category = Intl.pluralLogic(
      count,
      locale: frameworkLocale.languageCode,
      zero: 'zero',
      one: 'one',
      two: 'two',
      few: 'few',
      many: 'many',
      other: 'other',
    );
    final candidate = '$key.$category';
    return tr(
      vendorEnglishStrings.containsKey(candidate) ? candidate : '$key.other',
      args: {...args, 'count': count},
    );
  }

  String source(String english) {
    final key = _sourceKeys[english];
    if (key != null) return tr(key);
    for (final pattern in _patterns) {
      final match = pattern.regex.firstMatch(english);
      if (match != null) {
        return tr(
          pattern.key,
          args: {
            for (var i = 0; i < pattern.names.length; i++)
              pattern.names[i]: match[i + 1],
          },
        );
      }
    }
    return english;
  }

  Future<AppLanguagePack?> prepare(String next) async {
    if (next == 'en') return await repository.cachedPack('en');
    final cached = await repository.cachedPack(next);
    if (cached != null) return cached;
    var option = options
        .where((v) => v.code == next && v.version > 0)
        .firstOrNull;
    if (option == null) {
      await refresh(force: true);
      option = options
          .where((v) => v.code == next && v.version > 0)
          .firstOrNull;
    }
    if (option == null) {
      throw StateError('Language is not available for download');
    }
    final pack = await repository.download(option);
    await repository.storePack(pack, preserveCode: code);
    return pack;
  }

  void activate(String next, AppLanguagePack? pack) {
    code = next;
    _pack = pack;
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh({bool force = false}) async {
    if (refreshing) {
      _again |= force;
      return;
    }
    if (!force &&
        _lastSuccess != null &&
        DateTime.now().difference(_lastSuccess!) <
            const Duration(minutes: 15)) {
      return;
    }
    refreshing = true;
    try {
      final options = await repository.fetchManifest();
      if (_disposed) return;
      _options = options;
      final selectedCode = code;
      final option = options.where((v) => v.code == selectedCode).firstOrNull;
      if (option != null && option.version > (_pack?.option.version ?? 0)) {
        final pack = await repository.download(option);
        await repository.storePack(pack, preserveCode: code);
        if (!_disposed && code == selectedCode) _pack = pack;
      }
      _lastSuccess = DateTime.now();
      failed = false;
    } catch (_) {
      failed =
          true; /* Keep the working pack on every network/validation failure. */
    } finally {
      refreshing = false;
      if (!_disposed) notifyListeners();
      if (_again && !_disposed) {
        _again = false;
        unawaited(refresh(force: true));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class VendorLocalizationSync extends StatefulWidget {
  const VendorLocalizationSync({
    super.key,
    required this.localization,
    required this.child,
  });
  final VendorLocalization localization;
  final Widget child;
  @override
  State<VendorLocalizationSync> createState() => _VendorLocalizationSyncState();
}

class _VendorLocalizationSyncState extends State<VendorLocalizationSync>
    with WidgetsBindingObserver {
  late final LiveDataBinding _binding;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _binding = AppLiveData.instance.watch({
      'public:app_languages',
    }, (_) => widget.localization.refresh(force: true));
    unawaited(widget.localization.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.localization.refresh());
    }
  }

  @override
  void dispose() {
    _binding.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: widget.localization.direction,
    child: widget.child,
  );
}
