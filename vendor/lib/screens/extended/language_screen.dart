import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/app_settings_controller.dart';
import '../../services/vendor_tour_controller.dart';
import '../../widgets/trial/tour_anchor.dart';
import '../../widgets/vendor_page_scaffold.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, this.onSelected});

  /// First launch embeds this page; Settings opens it as a normal route.
  final VoidCallback? onSelected;
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _started = false;
  String? _pendingCode;
  bool _saving = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(AppSettingsScope.of(context).localization.refresh(force: true));
    }
  }

  Future<void> choose(String code) async {
    final settings = AppSettingsScope.of(context);
    if (settings.busy || _saving) return;
    setState(() => _saving = true);
    try {
      await settings.setLanguage(code);
      if (mounted) {
        if (widget.onSelected != null) {
          widget.onSelected!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settings.text(
                'Could not download or save this language. Your current language is unchanged. Retry when connected.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context),
        localization = settings.localization;
    final onboarding = widget.onSelected != null;
    final selectedCode = onboarding
        ? _pendingCode
        : settings.value.languageCode;
    final busy = _saving || settings.busy;
    return PopScope(
      canPop: !busy,
      child: VendorPageScaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.onSelected == null,
          title: Text(settings.text('Language')),
        ),
        bottomNavigationBar: onboarding
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('language-next'),
                    onPressed: busy || _pendingCode == null
                        ? null
                        : () => choose(_pendingCode!),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF80152C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(settings.tr('vendor.next.1ff57a29')),
                  ),
                ),
              )
            : null,
        body: TourAnchor(
          id: TourTargets.languages,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                settings.text('Choose your app language'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              if (localization.failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    settings.text(
                      'Offline or unable to refresh. Previously downloaded languages are still available.',
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final option in localization.options)
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: Semantics(
                          button: true,
                          selected: option.code == selectedCode,
                          child: Material(
                            color: option.code == selectedCode
                                ? const Color(0xFFF5E8EC)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: option.code == selectedCode
                                    ? const Color(0xFF80152C)
                                    : const Color(0xFFE8E5EB),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: ValueKey('language-option-${option.code}'),
                              onTap: busy
                                  ? null
                                  : () {
                                      if (onboarding) {
                                        setState(
                                          () => _pendingCode = option.code,
                                        );
                                      } else {
                                        choose(option.code);
                                      }
                                    },
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 84,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 22,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        option.nativeName,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: option.code == selectedCode
                                              ? const Color(0xFF80152C)
                                              : const Color(0xFF17171B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
