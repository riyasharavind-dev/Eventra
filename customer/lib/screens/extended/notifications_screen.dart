import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/app_settings_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppSettingsScope.of(context).syncNotificationPermission();
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

  Future<void> _toggle(bool enabled) async {
    try {
      final message = await AppSettingsScope.of(context)
          .setNotifications(enabled);
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Phone Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save notifications. Please retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.text('Notifications', 'அறிவிப்புகள்')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: Text(
              settings.text('Push notifications', 'புஷ் அறிவிப்புகள்'),
            ),
            subtitle: Text(
              settings.text(
                'Booking updates and account notifications',
                'முன்பதிவு மற்றும் கணக்கு அறிவிப்புகள்',
              ),
            ),
            value: settings.value.notificationsEnabled,
            onChanged: settings.busy ? null : _toggle,
          ),
          const SizedBox(height: 16),
          Text(
            settings.text(
              'You can change device notification permissions in your phone settings.',
              'தொலைபேசி அமைப்புகளில் அறிவிப்பு அனுமதிகளை மாற்றலாம்.',
            ),
          ),
          TextButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings_outlined),
            label: Text(
              settings.text('Open phone settings', 'தொலைபேசி அமைப்புகளைத் திற'),
            ),
          ),
          if (settings.busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
