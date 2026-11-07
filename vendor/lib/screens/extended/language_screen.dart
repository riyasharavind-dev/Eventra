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
    final settings = AppSettingsScope.of(context),
        colors = Theme.of(context).colorScheme;
    return VendorPageScaffold(
      appBar: AppBar(title: Text(settings.text('Language', 'மொழி'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            settings.text(
              'Choose your app language',
              'உங்கள் செயலி மொழியைத் தேர்வு செய்யவும்',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            settings.text(
              'The language changes only when you select an option below.',
              'கீழே ஒரு மொழியைத் தேர்வு செய்யும்போது மட்டுமே மொழி மாறும்.',
            ),
          ),
          const SizedBox(height: 24),
          ...const {'en': 'English', 'ta': 'தமிழ்'}.entries.map((e) {
            final selected = settings.value.languageCode == e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: selected
                    ? colors.primaryContainer
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: ValueKey('language-option-${e.key}'),
                  title: Text(
                    e.value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  leading: const Icon(Icons.language),
                  trailing: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: colors.primary,
                  ),
                  enabled: !settings.busy,
                  onTap: () => choose(context, e.key),
                ),
              ),
            );
          }),
          if (settings.busy) const Center(child: AppShimmerIndicator()),
        ],
      ),
    );
  }
}
