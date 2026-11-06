import 'package:flutter/material.dart';

import 'vendor_bottom_nav_bar.dart';

import 'package:permission_handler/permission_handler.dart';

import '../screens/extended/language_screen.dart';
import '../services/app_settings_controller.dart';
import 'common/profile_section_title.dart';

class AppSettingsSection extends StatefulWidget {
  const AppSettingsSection({super.key});
  @override
  State<AppSettingsSection> createState() => _AppSettingsSectionState();
}

class _AppSettingsSectionState extends State<AppSettingsSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppSettingsScope.of(context).syncNotificationPermission();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      AppSettingsScope.of(context).syncNotificationPermission();
    }
  }

  Future<void> toggle(bool enabled) async {
    final settings = AppSettingsScope.of(context);
    try {
      final message = await settings.setNotifications(enabled);
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: settings.text('Phone Settings', 'தொலைபேசி அமைப்புகள்'),
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settings.text(
                'Unable to save setting. Please retry.',
                'அமைப்பைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionTitle(settings.text('App Settings', 'செயலி அமைப்புகள்')),
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile(
                key: const ValueKey('notifications-toggle'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                secondary: Icon(
                  Icons.notifications_outlined,
                  color: VendorBottomNavBar.inactiveIconColor,
                ),
                title: Text(settings.text('Notifications', 'அறிவிப்புகள்')),
                subtitle: Text(
                  settings.text(
                    'Booking and account push notifications',
                    'முன்பதிவு மற்றும் கணக்கு அறிவிப்புகள்',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                value: settings.value.notificationsEnabled,
                onChanged: settings.busy ? null : toggle,
              ),
              const Divider(height: 1, indent: 60, endIndent: 16),
              ListTile(
                key: const ValueKey('open-language-screen'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Icon(
                  Icons.language,
                  color: VendorBottomNavBar.inactiveIconColor,
                ),
                title: Text(settings.text('Language', 'மொழி')),
                subtitle: Text(
                  settings.value.languageCode == 'ta' ? 'தமிழ்' : 'English',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: VendorBottomNavBar.inactiveIconColor,
                ),
                onTap: settings.busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const LanguageScreen(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
