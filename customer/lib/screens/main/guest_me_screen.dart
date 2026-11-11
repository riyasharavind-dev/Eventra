import 'package:flutter/material.dart';

import '../../core/theme/app_icon_colors.dart';
import '../../services/customer_access.dart';
import '../../widgets/auth/customer_auth_layout.dart';
import '../auth/customer_auth_screen.dart';
import '../extended/about_eventor_screen.dart';
import '../extended/language_screen.dart';
import '../extended/privacy_policy_screen.dart';
import '../extended/saved_services_screen.dart';
import '../extended/terms_and_conditions_screen.dart';

class GuestMeScreen extends StatelessWidget {
  const GuestMeScreen({super.key});
  void open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      title: Text(
        authText(context, 'Me', 'நான்'),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF17171B),
        ),
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      elevation: 0,
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
          child: Column(
            children: [
              const EventorAuthBrand(),
              const SizedBox(height: 20),
              Text(
                authText(
                  context,
                  'Find everything for your event',
                  'உங்கள் நிகழ்ச்சிக்கான அனைத்தையும் தேடுங்கள்',
                ),
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
                  'Browse freely. Sign in when you are ready to save services or make a booking.',
                  'சேவைகளைத் தாராளமாகப் பாருங்கள். சேமிக்க அல்லது முன்பதிவு செய்யத் தயாரானதும் உள்நுழையுங்கள்.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF73737D),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
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
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () => open(context, const CustomerAuthScreen()),
                  child: Text(authText(context, 'Login', 'உள்நுழை')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: authWine,
                    side: const BorderSide(color: authWine),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () =>
                      open(context, const CustomerAuthScreen(signup: true)),
                  child: Text(
                    authText(context, 'Create Account', 'கணக்கை உருவாக்கு'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: AppIconColors.standard,
                ),
                title: Text(
                  authText(context, 'Saved Services', 'சேமித்த சேவைகள்'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF17171B),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppIconColors.standard,
                ),
                onTap: () =>
                    CustomerAccess.open(context, const SavedServicesScreen()),
              ),
              const Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: Color(0xFFF0EDF0),
              ),
              ListTile(
                leading: const Icon(
                  Icons.language_rounded,
                  color: AppIconColors.standard,
                ),
                title: Text(
                  authText(context, 'Language', 'மொழி'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF17171B),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppIconColors.standard,
                ),
                onTap: () => open(context, const LanguageScreen()),
              ),
              const Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: Color(0xFFF0EDF0),
              ),
              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: AppIconColors.standard,
                ),
                title: Text(
                  authText(context, 'About Eventor', 'Eventor பற்றி'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF17171B),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppIconColors.standard,
                ),
                onTap: () => open(context, const AboutEventorScreen()),
              ),
              const Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: Color(0xFFF0EDF0),
              ),
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AppIconColors.standard,
                ),
                title: Text(
                  authText(context, 'Privacy Policy', 'தனியுரிமைக் கொள்கை'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF17171B),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppIconColors.standard,
                ),
                onTap: () => open(context, const PrivacyPolicyScreen()),
              ),
              const Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: Color(0xFFF0EDF0),
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppIconColors.standard,
                ),
                title: Text(
                  authText(
                    context,
                    'Terms & Conditions',
                    'விதிமுறைகள் மற்றும் நிபந்தனைகள்',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF17171B),
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppIconColors.standard,
                ),
                onTap: () => open(context, const TermsAndConditionsScreen()),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
