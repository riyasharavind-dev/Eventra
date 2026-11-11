import '../../services/customer_access.dart';
import '../extended/customer_address_screen.dart';
import '../../widgets/common/added_services_icon.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/confirmation_dialog.dart';
import '../../widgets/customer_profile_overview.dart';
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
import '../extended/my_profile_screen.dart';
import '../extended/saved_services_screen.dart';
import '../extended/my_reviews_screen.dart';
import '../extended/service_cart_screen.dart';
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

class _MeScreenState extends State<MeScreen>
    with WidgetsBindingObserver, LiveDataState<MeScreen> {
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
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppSettingsScope.of(context).syncNotificationPermission();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      AppSettingsScope.of(context).syncNotificationPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  String t(String en, String ta) => AppSettingsScope.of(context).text(en, ta);
  Future<void> _load({bool showLoading = false}) async {
    if (!mounted) return;
    if (widget.repository == null && !CustomerAccess.signedIn) {
      setState(() {
        _user = null;
        _loading = false;
        _failed = false;
      });
      return;
    }
    if (showLoading) setState(() => _loading = true);
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
    final publicScreen =
        screen is LanguageScreen ||
        screen is HelpSupportScreen ||
        screen is AboutEventorScreen ||
        screen is PrivacyPolicyScreen ||
        screen is TermsAndConditionsScreen;
    if (!publicScreen &&
        widget.repository == null &&
        !await CustomerAccess.requireSignIn(context)) {
      return;
    }
    if (!mounted) return;
    if (widget.onOpen != null) {
      widget.onOpen!(screen);
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (refresh && mounted) await _load();
  }

  Future<void> _logout() async {
    if (!CustomerAccess.signedIn || _loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: t('Log out?', 'வெளியேற வேண்டுமா?'),
        message: t(
          'Are you sure you want to log out of Eventor?',
          'Eventor-இலிருந்து வெளியேற விரும்புகிறீர்களா?',
        ),
        confirmLabel: CustomerAccess.signedIn
            ? t('Log Out', 'வெளியேறு')
            : t('Log in', 'உள்நுழை'),
        cancelLabel: t('Cancel', 'ரத்து'),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      try {
        await NotificationService.instance.removeToken();
      } catch (_) {
        /* Sign-out still proceeds offline. */
      }
      await _repo.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
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
    elevation: 2,
    shadowColor: wine.withValues(alpha: .06),
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.only(left: 60, right: 16),
              child: Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: .5),
              ),
            ),
          InkWell(
            key: ValueKey('me-${rows[index].id}'),
            onTap: rows[index].onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: rows[index].id == 'added-services'
                        ? const AddedServicesIcon(size: 20)
                        : Icon(
                            rows[index].icon,
                            size: 20,
                            color: const Color(0xFF73737D),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[index].title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          rows[index].subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: Color(0xFF73737D),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
  Future<void> _toggleNotifications(bool value) async {
    if (widget.repository == null &&
        !await CustomerAccess.requireSignIn(context)) {
      return;
    }
    if (!mounted) return;
    final settings = AppSettingsScope.of(context);
    try {
      final message = await settings.setNotifications(value);
      if (mounted && message != null) _message(message);
    } catch (_) {
      if (mounted) {
        _message(
          t(
            'Unable to save setting. Please retry.',
            'அமைப்பைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சி.',
          ),
        );
      }
    }
  }

  void _message(String message) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 16.0
        : 120.0 + MediaQuery.paddingOf(context).bottom;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
          content: Text(message),
        ),
      );
  }

  Widget _appSettings() {
    final settings = AppSettingsScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionTitle(t('App Settings', 'செயலி அமைப்புகள்')),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0EDF0)),
            boxShadow: [
              BoxShadow(
                color: wine.withValues(alpha: .05),
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
                  activeTrackColor: wine,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  secondary: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF73737D),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    t('Notifications', 'அறிவிப்புகள்'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    t(
                      'Booking and account push notifications',
                      'முன்பதிவு மற்றும் கணக்கு அறிவிப்புகள்',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF73737D),
                    ),
                  ),
                  value: settings.value.notificationsEnabled,
                  onChanged: settings.busy ? null : _toggleNotifications,
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
                  leading: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.language,
                      color: Color(0xFF73737D),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    t('Language', 'மொழி'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    settings.tamil ? 'தமிழ்' : 'English',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73737D),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF73737D),
                  ),
                  onTap: settings.busy
                      ? null
                      : () => _open(const LanguageScreen()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

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
        'customer-address',
        Icons.location_on_outlined,
        'Your Address',
        'உங்கள் முகவரி',
        _user?.address?.trim().isNotEmpty == true
            ? _user!.address!
            : 'Add your home or contact address',
        () => _open(const CustomerAddressScreen(), refresh: true),
      ),
      item(
        'added-services',
        Icons.checklist_rounded,
        'Added Services',
        'சேர்க்கப்பட்ட சேவைகள்',
        'Manage services and book them together',
        () => _open(const ServiceCartScreen()),
      ),
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
        child: AppShimmerRefreshIndicator(
          onRefresh: () => _load(showLoading: true),
          color: wine,
          loading: _loading,
          skeletonLayout: SkeletonLayout.profile,
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
                CustomerProfileOverview(
                  user: _user,
                  isGuest:
                      widget.repository == null && !CustomerAccess.signedIn,
                  onAuthenticated: _load,
                  onEdit: () => _open(const MyProfileScreen(), refresh: true),
                  onSaved: () => _open(const SavedServicesScreen()),
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
                _section(t('Profile', 'சுயவிவரம்'), [...profile, ...activity]),
                _appSettings(),
                _section(
                  t('Account & Security', 'கணக்கு மற்றும் பாதுகாப்பு'),
                  account,
                ),
                _section(t('Help & Information', 'உதவி மற்றும் தகவல்'), [
                  ...support,
                  ...legal,
                ]),
                FollowUsSection(
                  refreshKey: _generation,
                  loadLinks: widget.loadSocialLinks,
                ),
                if (CustomerAccess.signedIn) ...[
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
                        child: _loggingOut
                            ? const SizedBox.square(
                                dimension: 17,
                                child: AppShimmerIndicator(color: Colors.white),
                              )
                            : Text(
                                t('Log Out', 'வெளியேறு'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
