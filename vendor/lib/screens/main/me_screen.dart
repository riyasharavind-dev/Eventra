import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../widgets/vendor_bottom_nav_bar.dart';

import '../../widgets/common/global_search_bar.dart';
import '../../models/settings_search_item.dart';
import '../extended/language_screen.dart';
import '../../models/profile_statistics.dart';
import '../../repositories/profile_statistics_repository.dart';
import '../../widgets/vendor_profile_overview.dart';
import '../../widgets/common/profile_section_title.dart';
import '../extended/service_reviews_screen.dart';
import 'bookings_screen.dart';
import '../../models/business_model.dart';
import '../../models/social_link_model.dart';
import '../../widgets/follow_us_section.dart';
import '../../models/vendor_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/vendor_repository.dart';
import '../../services/app_settings_controller.dart';
import '../../services/notification_service.dart';
import '../../widgets/account_security_dialog.dart';
import '../../widgets/app_settings_section.dart';
import '../../widgets/common/confirmation_dialog.dart';
import '../extended/about_eventra_screen.dart';
import '../extended/business_details.dart';
import '../extended/help_support_screen.dart';
import '../extended/my_profile.dart';
import '../extended/privacy_policy_screen.dart';
import '../extended/terms_and_conditions_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({
    super.key,
    this.loadVendor,
    this.loadBusinesses,
    this.onLogout,
    this.loadSocialLinks,
    this.loadStatistics,
    this.onBookings,
    this.isActive = true,
  });

  final Future<VendorModel?> Function()? loadVendor;
  final Future<List<BusinessModel>> Function()? loadBusinesses;
  final Future<void> Function()? onLogout;
  final Future<List<SocialLinkModel>> Function()? loadSocialLinks;
  final Future<ProfileStatistics> Function(String vendorId)? loadStatistics;
  final VoidCallback? onBookings;
  final bool isActive;

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final _settingsKey = GlobalKey();
  final _followKey = GlobalKey();

  VendorModel? _vendor;
  List<BusinessModel> _businesses = [];

  bool _loading = true;
  bool _loggingOut = false;
  bool _confirmingLogout = false;

  int _loadGeneration = 0;
  int _statisticsGeneration = 0;

  ProfileStatistics? _statistics;
  bool _statisticsLoading = true;
  bool _statisticsFailed = false;

  static const _wine = Color(0xFF80152C);
  static const _background = Color(0xFFF8F8FA);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _text(String english, String tamil) =>
      AppSettingsScope.of(context).text(english, tamil);

  Future<void> _loadStatistics() async {
    final id = _vendor?.id;
    if (id == null || !mounted) return;

    final generation = ++_statisticsGeneration;

    setState(() {
      _statisticsLoading = _statistics == null;
      _statisticsFailed = false;
    });

    try {
      final data =
          await (widget.loadStatistics?.call(id) ??
              ProfileStatisticsRepository().load(id));

      if (!mounted ||
          generation != _statisticsGeneration ||
          _vendor?.id != id) {
        return;
      }

      setState(() {
        _statistics = data;
        _statisticsLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _statisticsGeneration) return;

      setState(() {
        _statisticsFailed = true;
        _statisticsLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    final generation = ++_loadGeneration;

    setState(() {
      _loading = true;
    });

    try {
      final vendor =
          await (widget.loadVendor?.call() ?? VendorRepository().getMyVendor());

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _vendor = vendor;
        _loading = false;
      });

      final statisticsRefresh = _loadStatistics();

      final businesses =
          await (widget.loadBusinesses?.call() ??
              BusinessRepository().getCurrentVendorBusinesses());

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _vendor = vendor;
        _businesses = businesses;
        _loading = false;
      });

      await statisticsRefresh;
    } catch (error) {
      debugPrint('Unable to load Me screen: $error');

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _open(Widget screen, {bool reload = false}) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    if (mounted && reload) {
      await _loadData();
    }
  }

  void _openBookings() {
    if (widget.onBookings != null) {
      widget.onBookings!();
    } else {
      _open(const BookingsScreen());
    }
  }

  void _openBusinessDetails() {
    _open(BusinessDetailsScreen(businesses: _businesses), reload: true);
  }

  Future<void> _showAboutMe() async {
    final about = _vendor?.aboutMe?.trim() ?? '';
    if (about.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _text('About Me', 'என்னைப் பற்றி'),
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(about, style: const TextStyle(height: 1.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accountAction(AccountSecurityAction action) async {
    await showAccountSecurityAction(context, action);

    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _confirmLogout() async {
    if (_loggingOut || _confirmingLogout) return;

    setState(() => _confirmingLogout = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => ConfirmationDialog(
          title: _text('Logout?', 'வெளியேற வேண்டுமா?'),
          message: _text(
            'Are you sure you want to log out of Eventra?',
            'Eventra கணக்கிலிருந்து வெளியேற விரும்புகிறீர்களா?',
          ),
          confirmLabel: _text('Logout', 'வெளியேறு'),
          cancelLabel: _text('Cancel', 'ரத்து செய்'),
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _loggingOut = true);

      if (widget.onLogout != null) {
        await widget.onLogout!();
        return;
      }

      try {
        await NotificationService.instance.removeToken();
      } catch (error) {
        debugPrint('Notification cleanup on logout was unavailable: $error');
      }

      await AuthRepository().signOut();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Unable to log out. Please try again.',
              'வெளியேற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
            ),
          ),
        ),
      );

      try {
        await NotificationService.instance.initialize();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
          _confirmingLogout = false;
        });
      }
    }
  }

  Widget _heading(String title) => ProfileSectionTitle(title);

  Widget _menuGroup(List<Widget> children) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: _wine.withValues(alpha: 0.06),
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 60, right: 16),
                child: Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                icon,
                size: 20,
                color: VendorBottomNavBar.inactiveIconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerMessage(IconData icon, String message) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _loadData,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(icon, size: 42, color: VendorBottomNavBar.inactiveIconColor),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    if (_loading && _vendor == null) {
      return const SizedBox(
        height: 330,
        child: Center(
          child: AppContentSkeleton(
            layout: SkeletonLayout.profile,
            rows: 0,
            bottomPadding: 16,
          ),
        ),
      );
    }

    if (_vendor == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _headerMessage(
          Icons.refresh_rounded,
          _text(
            'Unable to load profile.\nTap to retry.',
            'சுயவிவரத்தை ஏற்ற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VendorProfileOverview(
        vendor: _vendor!,
        statistics: _statistics,
        loading: _statisticsLoading,
        failed: _statisticsFailed,
        onEdit: () => _open(const MyProfileScreen(), reload: true),
        onBusiness: _openBusinessDetails,
        onAbout: _showAboutMe,
        onEvents: _openBookings,
        onReviews: () =>
            _open(const ServiceReviewsScreen(vendorMode: true), reload: true),
        onRetry: _loadStatistics,
      ),
    );
  }

  Widget _settingsSection() {
    final baseTheme = Theme.of(context);

    final settingsTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: _background,
      canvasColor: _background,
      cardColor: Colors.white,
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: Colors.white,
        surfaceContainerLowest: _background,
        surfaceContainerLow: _background,
        surfaceContainer: _background,
      ),
    );

    return Theme(data: settingsTheme, child: const AppSettingsSection());
  }

  // Compact logout button, centered.
  Widget _logoutButton() {
    return Center(
      child: SizedBox(
        width: 124,
        height: 40,
        child: FilledButton(
          onPressed: _loggingOut || _confirmingLogout ? null : _confirmLogout,
          style: FilledButton.styleFrom(
            backgroundColor: _wine,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _wine.withValues(alpha: 0.55),
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _loggingOut
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: AppShimmerIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _text('Logout', 'வெளியேறு'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  SettingsSearchItem _setting(
    String id,
    IconData icon,
    String title,
    String tamilTitle,
    String subtitle,
    String tamilSubtitle,
    VoidCallback onTap, {
    List<String> keywords = const [],
  }) => SettingsSearchItem(
    id: id,
    icon: icon,
    title: _text(title, tamilTitle),
    subtitle: _text(subtitle, tamilSubtitle),
    onTap: onTap,
    keywords: [title, tamilTitle, subtitle, tamilSubtitle, ...keywords],
  );

  void _revealSection(GlobalKey key) {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() => _searchQuery = '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;

      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          alignment: 0.08,
        );
      }
    });
  }

  Widget _searchResult(SettingsSearchItem item) => KeyedSubtree(
    key: ValueKey('setting-result-${item.id}'),
    child: _menuCard(
      icon: item.icon,
      title: item.title,
      subtitle: item.subtitle,
      onTap: item.onTap,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    final businessSubtitle = _businesses.isEmpty
        ? _text('Add your business', 'உங்கள் வணிகத்தைச் சேர்க்கவும்')
        : settings.tamil
        ? '${_businesses.length} வணிகங்கள்'
        : '${_businesses.length} business${_businesses.length == 1 ? '' : 'es'}';

    final profile = [
      _setting(
        'profile',
        Icons.person_outline_rounded,
        'My Profile',
        'எனது சுயவிவரம்',
        'Manage your personal information',
        'உங்கள் தனிப்பட்ட விவரங்களை நிர்வகிக்கவும்',
        () => _open(const MyProfileScreen(), reload: true),
        keywords: ['photo avatar dp name about personal சுயவிவரம்'],
      ),
      _setting(
        'business',
        Icons.storefront_outlined,
        'Business Details',
        'வணிக விவரங்கள்',
        businessSubtitle,
        businessSubtitle,
        _openBusinessDetails,
        keywords: [
          'shop address location map logo banner business வணிகம் கடை முகவரி',
        ],
      ),
    ];

    final appSettings = [
      _setting(
        'notifications',
        Icons.notifications_outlined,
        'Notifications',
        'அறிவிப்புகள்',
        'Booking and account push notifications',
        'முன்பதிவு மற்றும் கணக்கு அறிவிப்புகள்',
        () => _revealSection(_settingsKey),
        keywords: ['push alerts notification settings அறிவிப்பு'],
      ),
      _setting(
        'language',
        Icons.language,
        'Language',
        'மொழி',
        'English / Tamil',
        'ஆங்கிலம் / தமிழ்',
        () => _open(const LanguageScreen()),
        keywords: ['english tamil language settings மொழி தமிழ் ஆங்கிலம்'],
      ),
    ];

    final account = [
      _setting(
        'password',
        Icons.lock_outline_rounded,
        'Change Password',
        'கடவுச்சொல்லை மாற்று',
        'Update your sign-in password',
        'உள்நுழைவுக் கடவுச்சொல்லைப் புதுப்பிக்கவும்',
        () => _accountAction(AccountSecurityAction.password),
        keywords: ['account security login password கடவுச்சொல்'],
      ),
      _setting(
        'email',
        Icons.mail_outline_rounded,
        'Change Email',
        'மின்னஞ்சலை மாற்று',
        'Update your account email',
        'உங்கள் கணக்கு மின்னஞ்சலைப் புதுப்பிக்கவும்',
        () => _accountAction(AccountSecurityAction.email),
        keywords: ['account security mail மின்னஞ்சல்'],
      ),
      _setting(
        'phone',
        Icons.phone_outlined,
        'Phone Number',
        'தொலைபேசி எண்',
        'Manage your contact number',
        'உங்கள் தொடர்பு எண்ணை நிர்வகிக்கவும்',
        () => _accountAction(AccountSecurityAction.phone),
        keywords: ['account security mobile contact தொலைபேசி'],
      ),
      _setting(
        'delete',
        Icons.person_remove_outlined,
        'Delete Account',
        'கணக்கை நீக்கு',
        'Request account deletion for admin review',
        'கணக்கை நீக்க நிர்வாகியிடம் கோரிக்கை அனுப்பவும்',
        () => _accountAction(AccountSecurityAction.deleteAccount),
        keywords: ['account security remove deletion close கணக்கு நீக்கு'],
      ),
    ];

    final help = [
      _setting(
        'support',
        Icons.help_outline_rounded,
        'Help & Support',
        'உதவி மற்றும் ஆதரவு',
        'FAQs, contact support and track requests',
        'கேள்விகள், ஆதரவு மற்றும் கோரிக்கைகள்',
        () => _open(const HelpSupportScreen()),
        keywords: ['help information faq ticket contact support உதவி'],
      ),
      _setting(
        'about',
        Icons.info_outline_rounded,
        'About Eventra',
        'Eventra பற்றி',
        'Learn about Eventra Vendor',
        'Eventra Vendor பற்றித் தெரிந்துகொள்ளவும்',
        () => _open(const AboutEventraScreen()),
        keywords: ['help information company about பற்றி'],
      ),
      _setting(
        'privacy',
        Icons.privacy_tip_outlined,
        'Privacy Policy',
        'தனியுரிமைக் கொள்கை',
        'How Eventra handles your information',
        'உங்கள் தகவல்கள் எவ்வாறு கையாளப்படுகின்றன',
        () => _open(const PrivacyPolicyScreen()),
        keywords: ['help information legal privacy data தனியுரிமை'],
      ),
      _setting(
        'terms',
        Icons.description_outlined,
        'Terms & Conditions',
        'விதிமுறைகள் மற்றும் நிபந்தனைகள்',
        'Read the latest Eventra vendor terms',
        'சமீபத்திய விற்பனையாளர் விதிமுறைகளைப் படிக்கவும்',
        () => _open(const TermsAndConditionsScreen()),
        keywords: ['help information legal terms conditions விதிமுறைகள்'],
      ),
    ];

    final extra = [
      _setting(
        'follow',
        Icons.public,
        'Follow Us',
        'எங்களைப் பின்தொடருங்கள்',
        'Eventra social links',
        'Eventra சமூக இணைப்புகள்',
        () => _revealSection(_followKey),
        keywords: [
          'social instagram whatsapp facebook youtube telegram linkedin twitter community சமூகம்',
        ],
      ),
      _setting(
        'logout',
        Icons.logout,
        'Logout',
        'வெளியேறு',
        'Sign out of your account',
        'உங்கள் கணக்கிலிருந்து வெளியேறவும்',
        _confirmLogout,
        keywords: ['log out sign out exit வெளியேறு'],
      ),
    ];

    final searching = _searchQuery.trim().isNotEmpty;

    final results = [
      ...profile,
      ...appSettings,
      ...account,
      ...help,
      ...extra,
    ].where((item) => item.matches(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: AppShimmerRefreshIndicator(
          onRefresh: _loadData,
          color: _wine,
          child: ListView(
            key: const PageStorageKey('me-settings-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ME HEADING: BLACK
                    Text(
                      _text('Me', 'எனது கணக்கு'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlobalSearchBar(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      hintText: _text(
                        'Search settings, help and more',
                        'அமைப்புகள், உதவி மற்றும் பலவற்றைத் தேடுங்கள்',
                      ),
                      clearLabel: _text('Clear search', 'தேடலை அழி'),
                    ),
                  ],
                ),
              ),

              if (!searching) _profileHeader(),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 128),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (searching) ...[
                      _heading(_text('Search results', 'தேடல் முடிவுகள்')),
                      if (results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            _text(
                              'No matching settings. Try another word.',
                              'பொருந்தும் அமைப்புகள் இல்லை. வேறு சொல்லை முயற்சிக்கவும்.',
                            ),
                          ),
                        )
                      else
                        _menuGroup(results.map(_searchResult).toList()),
                    ] else ...[
                      _heading(
                        _text('Profile & Business', 'சுயவிவரம் மற்றும் வணிகம்'),
                      ),
                      _menuGroup(profile.map(_searchResult).toList()),
                      const SizedBox(height: 24),

                      KeyedSubtree(
                        key: _settingsKey,
                        child: _settingsSection(),
                      ),

                      const SizedBox(height: 28),
                      _heading(
                        _text(
                          'Account & Security',
                          'கணக்கு மற்றும் பாதுகாப்பு',
                        ),
                      ),
                      _menuGroup(account.map(_searchResult).toList()),
                      const SizedBox(height: 24),

                      _heading(
                        _text('Help & Information', 'உதவி மற்றும் தகவல்கள்'),
                      ),
                      _menuGroup(help.map(_searchResult).toList()),
                      const SizedBox(height: 24),

                      KeyedSubtree(
                        key: _followKey,
                        child: FollowUsSection(
                          refreshKey: _loadGeneration,
                          loadLinks: widget.loadSocialLinks,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // CENTERED COMPACT LOGOUT BUTTON
                      _logoutButton(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
