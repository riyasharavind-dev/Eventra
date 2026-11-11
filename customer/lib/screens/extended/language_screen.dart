import 'package:flutter/material.dart';

import '../../services/app_settings_controller.dart';
import '../../models/app_language_pack.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final localization = settings.localization;
    return ListenableBuilder(
      listenable: localization ?? settings,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(title: Text(settings.text('Language', 'மொழி'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              settings.text(
                'Choose your app language',
                'உங்கள் செயலி மொழியைத் தேர்வு செய்யவும்',
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17171B),
              ),
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount:
                  (localization?.options ?? [AppLanguageOption.english]).length,
              itemBuilder: (context, i) {
                final item =
                    (localization?.options ?? [AppLanguageOption.english])[i];
                final selected = item.code == settings.value.languageCode;
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected
                        ? const Color(0xFFF5E8EC)
                        : Colors.white,
                    foregroundColor: selected
                        ? const Color(0xFF80152C)
                        : const Color(0xFF17171B),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF80152C)
                          : const Color(0xFFF0EDF0),
                      width: selected ? 1.5 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: settings.busy
                      ? null
                      : () async {
                          try {
                            await settings.setLanguage(item.code);
                            if (context.mounted) Navigator.pop(context);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to download language. Retry when connected.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: Text(
                    item.nativeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
