import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../services/app_settings_controller.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  Future<void> choose(BuildContext context, String code) async {
    final settings = AppSettingsScope.of(context);
    if (settings.busy) {
      return;
    }
    try {
      await settings.setLanguage(code);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settings.text(
                'Unable to save language. Please retry.',
                'மொழியைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return VendorPageScaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8FA),
        surfaceTintColor: Colors.transparent,
        title: Text(
          settings.text('Language', 'மொழி'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
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
          const SizedBox(height: 6),
          Text(
            settings.text(
              'The language changes only when you select an option below.',
              'கீழே ஒரு மொழியைத் தேர்வு செய்யும்போது மட்டுமே மொழி மாறும்.',
            ),
            style: const TextStyle(color: Color(0xFF73737D), fontSize: 14),
          ),
          const SizedBox(height: 24),
          ...const {'en': 'English', 'ta': 'தமிழ்'}.entries.map((e) {
            final selected = settings.value.languageCode == e.key;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFF8FA) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? const Color(0xFF80152C) : const Color(0xFFF0EDF0),
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF80152C).withValues(alpha: selected ? 0.08 : 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  key: ValueKey('language-option-${e.key}'),
                  title: Text(
                    e.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: selected ? const Color(0xFF80152C) : const Color(0xFF17171B),
                    ),
                  ),
                  subtitle: Text(
                    e.key == 'en' ? 'English (Default)' : 'தமிழ் மொழி',
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? const Color(0xFF80152C).withValues(alpha: 0.7) : const Color(0xFF73737D),
                    ),
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFF5E8EC) : const Color(0xFFF4F2F4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.language_rounded,
                      color: selected ? const Color(0xFF80152C) : const Color(0xFF73737D),
                      size: 22,
                    ),
                  ),
                  trailing: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? const Color(0xFF80152C) : const Color(0xFFB8B5B8),
                    size: 24,
                  ),
                  enabled: !settings.busy,
                  onTap: () => choose(context, e.key),
                ),
              ),
            );
          }),
          if (settings.busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: AppShimmerIndicator(color: Color(0xFF80152C)),
              ),
            ),
        ],
      ),
    );
  }
}
