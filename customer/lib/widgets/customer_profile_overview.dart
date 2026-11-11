import 'package:flutter/material.dart';

import '../models/auth_model.dart';
import '../screens/auth/customer_auth_screen.dart';
import '../services/app_settings_controller.dart';

/// Customer identity using the same card proportions and actions as vendor Me.
class CustomerProfileOverview extends StatelessWidget {
  const CustomerProfileOverview({
    super.key,
    required this.user,
    required this.onEdit,
    required this.onSaved,
    this.isGuest = false,
    this.onAuthenticated,
  });
  final AuthModel? user;
  final bool isGuest;
  final VoidCallback? onAuthenticated;
  final VoidCallback onEdit, onSaved;
  static const wine = Color(0xFF80152C), gold = Color(0xFFFFCB48);
  Future<void> _openAuth(BuildContext context, {required bool signup}) async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CustomerAuthScreen(signup: signup)),
    );
    if (signedIn == true && context.mounted) onAuthenticated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final name = user?.name.trim();
    final displayName = name?.isNotEmpty == true
        ? name!
        : settings.text('Customer', 'வாடிக்கையாளர்');
    final address = user?.address?.trim();
    Widget initial() => ColoredBox(
      color: const Color(0xFFF5E8EC),
      child: Center(
        child: Text(
          displayName.isEmpty ? 'C' : displayName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: wine,
          ),
        ),
      ),
    );
    Widget action(
      String label,
      IconData icon,
      Color color,
      VoidCallback onTap,
    ) => Expanded(
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 17, color: Colors.white),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
    return Container(
      key: const ValueKey('customer-profile-overview'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: wine.withValues(alpha: .07),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (_, constraints) {
              final size = constraints.maxWidth > 450 ? 104.0 : 84.0;
              return Row(
                children: [
                  SizedBox(
                    width: size + 5,
                    height: size + 9,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        width: size,
                        height: size,
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: gold,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: isGuest
                              ? const ColoredBox(
                                  color: Color(0xFFF5E8EC),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: wine,
                                    size: 40,
                                  ),
                                )
                              : user?.avatarUrl?.trim().isNotEmpty == true
                              ? Image.network(
                                  user!.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) => initial(),
                                )
                              : initial(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGuest
                              ? settings.text(
                                  'Hello, Guest',
                                  'வணக்கம், விருந்தினரே',
                                )
                              : displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: wine,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isGuest
                              ? settings.text(
                                  'Browse services, explore vendors and plan your events.',
                                  'சேவைகளையும் சேவை வழங்குநர்களையும் பார்த்து உங்கள் நிகழ்வுகளைத் திட்டமிடுங்கள்.',
                                )
                              : address?.isNotEmpty == true
                              ? address!
                              : settings.text(
                                  'Manage your personal information',
                                  'உங்கள் தனிப்பட்ட தகவல்களை நிர்வகிக்கவும்',
                                ),
                          maxLines: isGuest ? null : 1,
                          overflow: isGuest ? null : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0EDF0)),
          const SizedBox(height: 12),
          Row(
            children: [
              action(
                isGuest
                    ? settings.text('Login', 'உள்நுழை')
                    : settings.text('Edit Profile', 'சுயவிவரத்தைத் திருத்து'),
                isGuest ? Icons.login_rounded : Icons.edit_outlined,
                wine,
                isGuest ? () => _openAuth(context, signup: false) : onEdit,
              ),
              const SizedBox(width: 10),
              action(
                isGuest
                    ? settings.text('Create Account', 'கணக்கை உருவாக்கு')
                    : settings.text('Saved Services', 'சேமித்த சேவைகள்'),
                isGuest
                    ? Icons.person_add_alt_1_outlined
                    : Icons.favorite_outline,
                gold,
                isGuest ? () => _openAuth(context, signup: true) : onSaved,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
