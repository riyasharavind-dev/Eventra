import '../../services/app_live_data.dart';
import '../../models/account_security_action.dart';

import 'package:flutter/material.dart';

import '../../models/auth_model.dart';
import '../../models/settings_search_item.dart';
import '../../models/social_link_model.dart';
import '../../repositories/auth_repository.dart';
import '../../services/app_settings_controller.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/global_search_bar.dart';
import '../../widgets/common/profile_section_title.dart';
import '../../widgets/follow_us_section.dart';
import '../auth/login_screen.dart';
import '../extended/my_profile_screen.dart';
import '../extended/saved_services_screen.dart';
import '../extended/my_reviews_screen.dart';
import '../extended/notifications_screen.dart';
import '../extended/language_screen.dart';
import '../extended/account_security_screen.dart';
import '../extended/help_support_screen.dart';
import '../extended/contact_support_screen.dart';
import '../extended/about_eventor_screen.dart';
import '../extended/privacy_policy_screen.dart';
import '../extended/terms_and_conditions_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({
    super.key,
    this.repository,
    this.loadSocialLinks,
    this.onOpen,
  });
  final AuthRepository? repository;
  final Future<List<SocialLinkModel>> Function()? loadSocialLinks;
  final ValueChanged<Widget>? onOpen;
  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> with LiveDataState<MeScreen> {
  @override
  Set<String> get liveDatasets => {'own:customers', 'own:users'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _load();
  }

  static const wine = Color(0xFF80152C);
  late final AuthRepository _repo;
  final _search = TextEditingController();
  AuthModel? _user;
  bool _loading = true, _failed = false, _loggingOut = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AuthRepository();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String t(String en, String ta) => AppSettingsScope.of(context).text(en, ta);
  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final user = await _repo.getAuthUser();
      if (!mounted || generation != _generation) return;
      setState(() {
        _user = user;
        _loading = false;
        _failed = user == null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _open(Widget screen, {bool refresh = false}) async {
    if (widget.onOpen != null) {
      widget.onOpen!(screen);
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (refresh && mounted) await _load();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Log out?', 'வெளியேற வேண்டுமா?')),
        content: Text(
          t(
            'Are you sure you want to log out of Eventor?',
            'Eventor-இலிருந்து வெளியேற விரும்புகிறீர்களா?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Cancel', 'ரத்து')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Log Out', 'வெளியேறு')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await NotificationService.instance.removeToken();
      await _repo.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Unable to log out. Please retry.',
                'வெளியேற முடியவில்லை. மீண்டும் முயற்சி.',
              ),
            ),
          ),
        );
      }
    }
  }

  SettingsSearchItem item(
    String id,
    IconData icon,
    String title,
    String ta,
    String subtitle,
    VoidCallback action,
  ) => SettingsSearchItem(
    id: id,
    icon: icon,
    title: t(title, ta),
    subtitle: subtitle,
    onTap: action,
    keywords: [title, ta, subtitle],
  );
  Widget _group(List<SettingsSearchItem> rows) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: 58, endIndent: 16),
          ListTile(
            key: ValueKey('me-${rows[index].id}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            leading: Icon(rows[index].icon, color: wine),
            title: Text(
              rows[index].title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              rows[index].subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF777783)),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF777783)),
            onTap: rows[index].onTap,
          ),
        ],
      ],
    ),
  );
  Widget _section(String heading, List<SettingsSearchItem> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [ProfileSectionTitle(heading), _group(rows)],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final profile = [
      item(
        'profile',
        Icons.person_outline_rounded,
        'My Profile',
        'எனது சுயவிவரம்',
        'Manage your personal information',
        () => _open(const MyProfileScreen(), refresh: true),
      ),
    ];
    final activity = [
      item(
        'saved',
        Icons.favorite_outline,
        'Saved Services',
        'சேமித்த சேவைகள்',
        'Your favourite services on this device',
        () => _open(const SavedServicesScreen()),
      ),
      item(
        'reviews',
        Icons.star_outline_rounded,
        'My Reviews',
        'எனது மதிப்புரைகள்',
        'Review completed services and read vendor replies',
        () => _open(const MyReviewsScreen()),
      ),
    ];
    final app = [
      item(
        'notifications',
        Icons.notifications_outlined,
        'Notifications',
        'அறிவிப்புகள்',
        settings.value.notificationsEnabled
            ? t('Enabled', 'இயக்கப்பட்டது')
            : t('Disabled', 'முடக்கப்பட்டது'),
        () => _open(const NotificationsScreen()),
      ),
      item(
        'language',
        Icons.language,
        'Language',
        'மொழி',
        settings.tamil ? 'தமிழ்' : 'English',
        () => _open(const LanguageScreen()),
      ),
    ];
    final account = [
      item(
        'password',
        Icons.lock_outline,
        'Change Password',
        'கடவுச்சொல்லை மாற்று',
        'Update your sign-in password',
        () => _open(
          const AccountSecurityScreen(action: AccountSecurityAction.password),
        ),
      ),
      item(
        'email',
        Icons.mail_outline,
        'Change Email',
        'மின்னஞ்சலை மாற்று',
        'Update your account email',
        () => _open(
          const AccountSecurityScreen(action: AccountSecurityAction.email),
          refresh: true,
        ),
      ),
      item(
        'phone',
        Icons.phone_outlined,
        'Phone Number',
        'தொலைபேசி எண்',
        'Manage your contact number',
        () => _open(
          const AccountSecurityScreen(action: AccountSecurityAction.phone),
          refresh: true,
        ),
      ),
      item(
        'delete',
        Icons.person_remove_outlined,
        'Delete Account',
        'கணக்கை நீக்கு',
        'Request account deletion for admin review',
        () => _open(
          const AccountSecurityScreen(
            action: AccountSecurityAction.deleteAccount,
          ),
        ),
      ),
    ];
    final support = [
      item(
        'help',
        Icons.help_outline,
        'Help & Support',
        'உதவி மற்றும் ஆதரவு',
        'FAQs and your support requests',
        () => _open(const HelpSupportScreen()),
      ),
      item(
        'contact',
        Icons.headset_mic_outlined,
        'Contact Support',
        'ஆதரவைத் தொடர்புகொள்',
        'Get help from the Eventor team',
        () => _open(const ContactSupportScreen()),
      ),
    ];
    final legal = [
      item(
        'about',
        Icons.info_outline,
        'About Eventor',
        'Eventor பற்றி',
        'Learn about Eventor',
        () => _open(
          AboutEventorScreen(languageCode: settings.value.languageCode),
        ),
      ),
      item(
        'privacy',
        Icons.privacy_tip_outlined,
        'Privacy Policy',
        'தனியுரிமைக் கொள்கை',
        'How your information is handled',
        () => _open(
          PrivacyPolicyScreen(languageCode: settings.value.languageCode),
        ),
      ),
      item(
        'terms',
        Icons.description_outlined,
        'Terms & Conditions',
        'விதிமுறைகள்',
        'Read the latest customer terms',
        () => _open(
          TermsAndConditionsScreen(languageCode: settings.value.languageCode),
        ),
      ),
    ];
    final searching = _search.text.trim().isNotEmpty;
    final results = [
      ...profile,
      ...activity,
      ...app,
      ...account,
      ...support,
      ...legal,
    ].where((row) => row.matches(_search.text)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: wine,
          child: ListView(
            key: const PageStorageKey('customer-me-menu'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 128),
            children: [
              Text(
                t('Me', 'எனது கணக்கு'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              GlobalSearchBar(
                controller: _search,
                onChanged: (_) => setState(() {}),
                hintText: t(
                  'Search settings, help and more',
                  'அமைப்புகள், உதவி மற்றும் பலவற்றைத் தேடுங்கள்',
                ),
              ),
              const SizedBox(height: 20),
              if (searching) ...[
                ProfileSectionTitle(t('Search results', 'தேடல் முடிவுகள்')),
                if (results.isEmpty)
                  Text(
                    t(
                      'No matching settings. Try another word.',
                      'பொருந்தும் அமைப்புகள் இல்லை.',
                    ),
                  )
                else
                  _group(results),
              ] else ...[
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFF4E6EB),
                      backgroundImage: _user?.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(_user!.avatarUrl!)
                          : null,
                      child: _user?.avatarUrl?.isNotEmpty == true
                          ? null
                          : const Icon(Icons.person_outline, color: wine),
                    ),
                    title: Text(
                      _loading
                          ? t('Loading profile…', 'சுயவிவரம் ஏற்றப்படுகிறது…')
                          : _user?.name ?? t('Customer', 'வாடிக்கையாளர்'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(_user?.email ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const MyProfileScreen(), refresh: true),
                  ),
                ),
                if (_failed)
                  TextButton(
                    onPressed: _load,
                    child: Text(
                      t(
                        'Unable to load profile. Retry',
                        'சுயவிவரத்தை ஏற்ற முடியவில்லை. மீண்டும் முயற்சி',
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _section(t('Profile', 'சுயவிவரம்'), profile),
                _section(t('My Activity', 'எனது செயல்பாடுகள்'), activity),
                _section(t('App Settings', 'செயலி அமைப்புகள்'), app),
                _section(
                  t('Account & Security', 'கணக்கு மற்றும் பாதுகாப்பு'),
                  account,
                ),
                _section(t('Support', 'ஆதரவு'), support),
                _section(t('About & Legal', 'பற்றி மற்றும் சட்டம்'), legal),
                FollowUsSection(
                  refreshKey: _generation,
                  loadLinks: widget.loadSocialLinks,
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 124,
                    height: 40,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: wine,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loggingOut ? null : _logout,
                      child: Text(
                        _loggingOut
                            ? t('Logging out…', 'வெளியேறுகிறது…')
                            : t('Log Out', 'வெளியேறு'),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
