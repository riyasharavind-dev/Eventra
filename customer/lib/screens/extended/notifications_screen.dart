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
              label: AppSettingsScope.translate(
                context,
                "customer.phone_settings.7e39991b",
              ),
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_save_notifications_please_retry.0a7af498",
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
    const wine = Color(0xFF80152C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          settings.text('Notifications', 'அறிவிப்புகள்'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF17171B),
          ),
        ),
        backgroundColor: const Color(0xFFF8F8FA),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0EDF0)),
              boxShadow: [
                BoxShadow(
                  color: wine.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              activeTrackColor: wine,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              secondary: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E8EC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: wine,
                  size: 20,
                ),
              ),
              title: Text(
                settings.text('Push notifications', 'புஷ் அறிவிப்புகள்'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF17171B),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  settings.text(
                    'Booking updates and account notifications',
                    'முன்பதிவு மற்றும் கணக்கு அறிவிப்புகள்',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF73737D),
                  ),
                ),
              ),
              value: settings.value.notificationsEnabled,
              onChanged: settings.busy ? null : _toggle,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              settings.text(
                'You can change device notification permissions in your phone settings.',
                'தொலைபேசி அமைப்புகளில் அறிவிப்பு அனுமதிகளை மாற்றலாம்.',
              ),
              style: const TextStyle(fontSize: 13, color: Color(0xFF73737D), height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: wine,
              side: const BorderSide(color: wine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(
              settings.text('Open phone settings', 'தொலைபேசி அமைப்புகளைத் திற'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (settings.busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: wine),
          ],
        ],
      ),
    );
  }
}
