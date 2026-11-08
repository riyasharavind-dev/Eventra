import 'package:eventor_vendor/core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';

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
        final messenger = ScaffoldMessenger.of(context);
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: settings.text('Phone Settings', 'தொலைபேசி அமைப்புகள்'),
              onPressed: () async {
                try {
                  final opened = await openAppSettings();
                  if (!opened) throw StateError('Settings unavailable');
                } catch (_) {
                  if (!mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.removeCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        settings.text(
                          'Unable to open Phone Settings. Open them manually.',
                          'தொலைபேசி அமைப்புகளைத் திறக்க முடியவில்லை. நேரடியாகத் திறக்கவும்.',
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
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
    final settings = AppSettingsScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionTitle(settings.text('App Settings', 'செயலி அமைப்புகள்')),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0EDF0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF80152C).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('notifications-toggle'),
                  activeTrackColor: const Color(0xFF80152C),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  secondary: SizedBox(
                    width: 38,
                    height: 38,
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppIconColors.standard,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    settings.text('Notifications', 'அறிவிப்புகள்'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    settings.text(
                      'Booking and account push notifications',
                      'முன்பதிவு மற்றும் கணக்கு அறிவிப்புகள்',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF73737D),
                    ),
                  ),
                  value: settings.value.notificationsEnabled,
                  onChanged: settings.busy ? null : toggle,
                ),
                const Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 16,
                  color: Color(0xFFF0EDF0),
                ),
                ListTile(
                  key: const ValueKey('open-language-screen'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: SizedBox(
                    width: 38,
                    height: 38,
                    child: const Icon(
                      Icons.language,
                      color: AppIconColors.standard,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    settings.text('Language', 'மொழி'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    settings.value.languageCode == 'ta' ? 'தமிழ்' : 'English',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73737D),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppIconColors.standard,
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
        ),
      ],
    );
  }
}
