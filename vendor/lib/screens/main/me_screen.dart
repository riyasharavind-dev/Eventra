import '../../services/vendor_tour_controller.dart';
import '../trial/vendor_trial_screen.dart';

import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/app_live_data.dart';
import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../widgets/common/global_search_bar.dart';
import '../../models/settings_search_item.dart';
import '../extended/language_screen.dart';
import '../../models/profile_statistics.dart';
import '../../repositories/profile_statistics_repository.dart';
import '../../widgets/vendor_profile_overview.dart';
import '../../widgets/common/profile_section_title.dart';
import '../extended/customer_reviews_screen.dart';
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
import '../extended/about_eventor_screen.dart';
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

class _MeScreenState extends State<MeScreen> with LiveDataState<MeScreen> {
  @override
  Set<String> get liveDatasets => {
    'own:vendors',
    'own:businesses',
    'own:bookings',
    'own:service_reviews',
    'own:service_metrics',
    'own:users',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _loadData();
  }

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
    VendorTourController.instance.addListener(_prepareTour);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareTour());
  }

  void _prepareTour() {
    if (!mounted ||
        !VendorTourController.instance.active ||
        VendorTourController.instance.step != 5) {
      return;
    }
    if (_searchQuery.isNotEmpty) {
      _searchController.clear();
      setState(() => _searchQuery = '');
    }
  }

  @override
  void dispose() {
    VendorTourController.instance.removeListener(_prepareTour);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    final id = _vendor?.id;
    if (id == null || !mounted) return;

    final generation = ++_statisticsGeneration;

    setState(() {
      _statisticsLoading = _loading && _statistics == null;
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

  Future<void> _loadData({bool showLoading = false}) async {
    if (!mounted) return;

    final generation = ++_loadGeneration;

    setState(() {
      _loading = showLoading || _loading;
    });

    try {
      final businessesFuture =
          (widget.loadBusinesses?.call() ??
                  BusinessRepository().getCurrentVendorBusinesses())
              .then<Object>((v) => v, onError: (Object e) => e);
      final vendor =
          await (widget.loadVendor?.call() ?? VendorRepository().getMyVendor());

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _vendor = vendor;
      });

      final statisticsRefresh = _loadStatistics();

      final result = await businessesFuture;
      if (result is! List<BusinessModel>) throw result;
      final businesses = result;

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _vendor = vendor;
        _businesses = businesses;
      });

      await statisticsRefresh;
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loading = false);
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
                  AppSettingsScope.translate(
                    context,
                    "vendor.about_me.0bf7f38a",
                  ),
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
          title: AppSettingsScope.translate(context, "vendor.logout.53b2ce73"),
          message: AppSettingsScope.translate(
            context,
            "vendor.are_you_sure_you_want_to_log_out_of_eventor.c93c270b",
          ),
          confirmLabel: AppSettingsScope.translate(
            context,
            "vendor.logout.d0527e4b",
          ),
          cancelLabel: AppSettingsScope.translate(
            context,
            "vendor.cancel.19766ed6",
          ),
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
            AppSettingsScope.translate(
              context,
              "vendor.unable_to_log_out_please_try_again.9fae72f9",
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
              child: Icon(icon, size: 20, color: AppIconColors.standard),
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
              color: AppIconColors.standard,
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
              Icon(icon, size: 42, color: AppIconColors.standard),
              const SizedBox(height: 14),
              Text(
                AppSettingsScope.source(context, message),
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
    if (_loading && _vendor == null) return const SizedBox.shrink();

    if (_vendor == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _headerMessage(
          Icons.refresh_rounded,
          AppSettingsScope.translate(
            context,
            "vendor.unable_to_load_profile_tap_to_retry.c4e4a7a0",
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
        onReviews: () => _open(const CustomerReviewsScreen(), reload: true),
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
                  AppSettingsScope.translate(context, "vendor.logout.d0527e4b"),
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
    String subtitle,
    VoidCallback onTap, {
    List<String> keywords = const [],
  }) => SettingsSearchItem(
    id: id,
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    keywords: [title, subtitle, ...keywords],
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
    final businessSubtitle = _businesses.isEmpty
        ? AppSettingsScope.translate(
            context,
            "vendor.add_your_business.eb580491",
          )
        : AppSettingsScope.localizationOf(context)
              .plural('common.business_count', _businesses.length);

    final profile = [
      _setting(
        'profile',
        Icons.person_outline_rounded,
        AppSettingsScope.translate(context, "vendor.my_profile.991bfa01"),
        AppSettingsScope.translate(
          context,
          "vendor.manage_your_personal_information.070d5375",
        ),
        () => _open(const MyProfileScreen(), reload: true),
        keywords: ['photo avatar dp name about personal '],
      ),
      _setting(
        'business',
        Icons.storefront_outlined,
        AppSettingsScope.translate(context, "vendor.business_details.502d1ed8"),
        businessSubtitle,
        _openBusinessDetails,
        keywords: ['shop address location map logo banner business   '],
      ),
      _setting(
        'customer-reviews',
        Icons.rate_review_outlined,
        AppSettingsScope.translate(context, "vendor.customer_reviews.8f8b1729"),
        AppSettingsScope.translate(
          context,
          "vendor.read_and_reply_to_reviews_across_your_busines.001ace06",
        ),
        () => _open(const CustomerReviewsScreen(), reload: true),
        keywords: ['customer reviews ratings feedback replies  '],
      ),
    ];

    final appSettings = [
      _setting(
        'notifications',
        Icons.notifications_outlined,
        AppSettingsScope.translate(context, "vendor.notifications.78801183"),
        AppSettingsScope.translate(
          context,
          "vendor.booking_and_account_push_notifications.74a88167",
        ),
        () => _revealSection(_settingsKey),
        keywords: ['push alerts notification settings '],
      ),
      _setting(
        'language',
        Icons.language,
        AppSettingsScope.translate(context, "vendor.language.a4fe6526"),
        AppSettingsScope.translate(context, "vendor.english_tamil.7f10956b"),
        () => _open(const LanguageScreen()),
        keywords: ['english tamil language settings   '],
      ),
    ];

    final account = [
      _setting(
        'password',
        Icons.lock_outline_rounded,
        AppSettingsScope.translate(context, "vendor.change_password.a949f462"),
        AppSettingsScope.translate(
          context,
          "vendor.update_your_sign_in_password.0aca1913",
        ),
        () => _accountAction(AccountSecurityAction.password),
        keywords: ['account security login password '],
      ),
      _setting(
        'email',
        Icons.mail_outline_rounded,
        AppSettingsScope.translate(context, "vendor.change_email.18c3f2d5"),
        AppSettingsScope.translate(
          context,
          "vendor.update_your_account_email.cb6f1c35",
        ),
        () => _accountAction(AccountSecurityAction.email),
        keywords: ['account security mail '],
      ),
      _setting(
        'phone',
        Icons.phone_outlined,
        AppSettingsScope.translate(context, "vendor.phone_number.72dba9ae"),
        AppSettingsScope.translate(
          context,
          "vendor.manage_your_contact_number.2a2b01c9",
        ),
        () => _accountAction(AccountSecurityAction.phone),
        keywords: ['account security mobile contact '],
      ),
      _setting(
        'delete',
        Icons.person_remove_outlined,
        AppSettingsScope.translate(context, "vendor.delete_account.c031bf99"),
        AppSettingsScope.translate(
          context,
          "vendor.request_account_deletion_for_admin_review.e62fb6ef",
        ),
        () => _accountAction(AccountSecurityAction.deleteAccount),
        keywords: ['account security remove deletion close  '],
      ),
    ];

    final help = [
      _setting(
        'app-guide',
        Icons.school_outlined,
        AppSettingsScope.translate(
          context,
          "vendor.app_guide_restart_tour.a7a9e5bf",
        ),
        AppSettingsScope.translate(
          context,
          "vendor.learn_the_app_and_practice_a_sample_booking.6cb715a0",
        ),
        () => VendorTrialScreen.open(context, restart: true),
        keywords: ['tutorial onboarding trial tour practice guide help  '],
      ),
      _setting(
        'support',
        Icons.help_outline_rounded,
        AppSettingsScope.translate(context, "vendor.help_support.1f8ecc24"),
        AppSettingsScope.translate(
          context,
          "vendor.faqs_contact_support_and_track_requests.f8c8dc7b",
        ),
        () => _open(const HelpSupportScreen()),
        keywords: ['help information faq ticket contact support '],
      ),
      _setting(
        'about',
        Icons.info_outline_rounded,
        AppSettingsScope.translate(context, "vendor.about_eventor.3495d1b2"),
        AppSettingsScope.translate(
          context,
          "vendor.learn_about_eventor_vendor.339f91f5",
        ),
        () => _open(const AboutEventorScreen()),
        keywords: ['help information company about '],
      ),
      _setting(
        'privacy',
        Icons.privacy_tip_outlined,
        AppSettingsScope.translate(context, "vendor.privacy_policy.506ff394"),
        AppSettingsScope.translate(
          context,
          "vendor.how_eventor_handles_your_information.ce218968",
        ),
        () => _open(const PrivacyPolicyScreen()),
        keywords: ['help information legal privacy data '],
      ),
      _setting(
        'terms',
        Icons.description_outlined,
        AppSettingsScope.translate(context, "vendor.terms_conditions.173f5f9f"),
        AppSettingsScope.translate(
          context,
          "vendor.read_the_latest_eventor_vendor_terms.8846c775",
        ),
        () => _open(const TermsAndConditionsScreen()),
        keywords: ['help information legal terms conditions '],
      ),
    ];

    final extra = [
      _setting(
        'follow',
        Icons.public,
        AppSettingsScope.translate(context, "vendor.follow_us.e2514497"),
        AppSettingsScope.translate(
          context,
          "vendor.eventor_social_links.cd63b32b",
        ),
        () => _revealSection(_followKey),
        keywords: [
          'social instagram whatsapp facebook youtube telegram linkedin twitter community ',
        ],
      ),
      _setting(
        'logout',
        Icons.logout,
        AppSettingsScope.translate(context, "vendor.logout.d0527e4b"),
        AppSettingsScope.translate(
          context,
          "vendor.sign_out_of_your_account.1083b824",
        ),
        _confirmLogout,
        keywords: ['log out sign out exit '],
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
          onRefresh: () => _loadData(showLoading: true),
          loading: _loading,
          skeletonLayout: SkeletonLayout.profile,
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
                      AppSettingsScope.translate(context, "vendor.me.d30af076"),
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
                      hintText: AppSettingsScope.translate(
                        context,
                        "vendor.search_settings_help_and_more.d6ae2d99",
                      ),
                      clearLabel: AppSettingsScope.translate(
                        context,
                        "vendor.clear_search.3b7ea517",
                      ),
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
                      _heading(
                        AppSettingsScope.translate(
                          context,
                          "vendor.search_results.e978b00d",
                        ),
                      ),
                      if (results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            AppSettingsScope.translate(
                              context,
                              "vendor.no_matching_settings_try_another_word.9ae141ea",
                            ),
                          ),
                        )
                      else
                        _menuGroup(results.map(_searchResult).toList()),
                    ] else ...[
                      _heading(
                        AppSettingsScope.translate(
                          context,
                          "vendor.profile_business.2f075b38",
                        ),
                      ),
                      _menuGroup(profile.map(_searchResult).toList()),
                      const SizedBox(height: 24),

                      KeyedSubtree(
                        key: _settingsKey,
                        child: _settingsSection(),
                      ),

                      const SizedBox(height: 28),
                      _heading(
                        AppSettingsScope.translate(
                          context,
                          "vendor.account_security.4fc94a35",
                        ),
                      ),
                      _menuGroup(account.map(_searchResult).toList()),
                      const SizedBox(height: 24),

                      _heading(
                        AppSettingsScope.translate(
                          context,
                          "vendor.help_information.bab7d064",
                        ),
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
