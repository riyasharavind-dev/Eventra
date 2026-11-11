import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_settings_controller.dart';
import '../../models/app_language_pack.dart';
import '../../widgets/auth/customer_auth_layout.dart';

class CustomerLanguageEntryScreen extends StatefulWidget {
  const CustomerLanguageEntryScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;
  static const preferenceKey = 'eventor.customer.language_entry_completed.v1';
  @override
  State<CustomerLanguageEntryScreen> createState() => _LanguageEntryState();
}

class _LanguageEntryState extends State<CustomerLanguageEntryScreen> {
  String? selected;
  bool saving = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    selected ??= AppSettingsScope.of(context).value.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final localization = settings.localization;
    return ListenableBuilder(
      listenable: localization ?? settings,
      builder: (context, _) {
        final options = [
          AppLanguageOption.english,
          ...?localization?.options.where((o) => o.code != 'en'),
        ];
        return CustomerAuthLayout(
          showBack: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EventorAuthBrand(),
              const SizedBox(height: 45),
              Text(
                authText(
                  context,
                  'Choose your language',
                  'உங்கள் மொழியைத் தேர்வு செய்யவும்',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 30),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final active = selected == option.code;
                  return OutlinedButton(
                    key: ValueKey('entry-language-${option.code}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: active
                          ? authWine
                          : const Color(0xFF17171B),
                      backgroundColor: active
                          ? const Color(0xFFF5E8EC)
                          : Colors.white,
                      side: BorderSide(
                        color: active ? authWine : const Color(0xFFF0EDF0),
                        width: active ? 1.5 : 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () => setState(() => selected = option.code),
                    child: Text(
                      option.nativeName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(error!, style: const TextStyle(color: authWine)),
                ),
              const SizedBox(height: 35),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: authWine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await settings.setLanguage(selected ?? 'en');
                            if (!await (await SharedPreferences.getInstance())
                                .setBool(
                                  CustomerLanguageEntryScreen.preferenceKey,
                                  true,
                                )) {
                              throw StateError('Unable to save');
                            }
                            if (mounted) widget.onComplete();
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => error = authText(
                                  context,
                                  'Unable to save language. Check your connection and retry.',
                                  'மொழியைச் சேமிக்க முடியவில்லை. இணைய இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  child: Text(
                    authText(
                      context,
                      saving ? 'Please wait…' : 'Next',
                      saving ? 'சற்று காத்திருக்கவும்…' : 'அடுத்து',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
