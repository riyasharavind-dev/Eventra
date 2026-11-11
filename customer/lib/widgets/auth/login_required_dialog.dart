import 'package:flutter/material.dart';

import 'customer_auth_layout.dart';

enum CustomerLoginChoice { login, signup }

class CustomerLoginDialog extends StatelessWidget {
  const CustomerLoginDialog({super.key});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeroIcon(compact: true),
                  const SizedBox(height: 16),
                  Text(
                    authText(context, 'Login Required', 'உள்நுழைவு தேவை'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17171B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authText(
                      context,
                      'Please login or create an account to book this service.',
                      'இந்த சேவையை முன்பதிவு செய்ய உள்நுழையவும் அல்லது கணக்கை உருவாக்கவும்.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF73737D),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: authWine,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, CustomerLoginChoice.login),
                      child: Text(authText(context, 'Login', 'உள்நுழை')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF5E8EC),
                        foregroundColor: authWine,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, CustomerLoginChoice.signup),
                      child: Text(
                        authText(context, 'Create Account', 'கணக்கை உருவாக்கு'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      authText(context, 'Maybe Later', 'பிறகு பார்க்கலாம்'),
                      style: const TextStyle(
                        color: Color(0xFF73737D),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              tooltip: authText(context, 'Close', 'மூடு'),
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Color(0xFF73737D),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}
