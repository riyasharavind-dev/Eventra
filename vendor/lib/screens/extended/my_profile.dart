import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/vendor_model.dart';
import '../../repositories/vendor_repository.dart';
import '../../services/app_settings_controller.dart';
import '../../widgets/account_security_dialog.dart';
import '../../widgets/profile_image_cropper.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key, this.repository});

  final VendorRepository? repository;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  static const Color _wine = Color(0xFF80152C);
  static const Color _gold = Color(0xFFFFCB48);
  static const Color _background = Color(0xFFF8F8FA);

  final _formKey = GlobalKey<FormState>();
  final _aboutController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _preferredContactLanguage;

  late final VendorRepository _vendorRepository;

  final ImagePicker _imagePicker = ImagePicker();

  VendorModel? _vendor;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isPickingProfileImage = false;

  String? _errorMessage;

  bool get _busy => _isSaving || _isUploadingImage || _isPickingProfileImage;

  @override
  void initState() {
    super.initState();
    _vendorRepository = widget.repository ?? VendorRepository();
    _loadVendor();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _profileTitle =>
      AppSettingsScope.translate(context, "vendor.personal_details.3a886778");

  Future<void> _loadVendor() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final VendorModel? vendor = await _vendorRepository.getMyVendor();

      if (vendor == null) {
        throw Exception('Vendor profile not found.');
      }

      if (!mounted) return;

      _nameController.text = vendor.name;
      _emailController.text = vendor.email;
      _phoneController.text = vendor.phone ?? '';
      _aboutController.text = vendor.aboutMe ?? '';
      _preferredContactLanguage = vendor.preferredContactLanguage;

      setState(() {
        _vendor = vendor;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(e);
      });
    }
  }

  Future<void> _pickProfileImage() async {
    if (_isUploadingImage || _isPickingProfileImage) return;

    _isPickingProfileImage = true;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      final cropped = await ProfileImageCropper.crop(context, pickedFile);

      if (!mounted || cropped == null) return;

      await _uploadProfileImage(cropped);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e), isError: true);
    } finally {
      _isPickingProfileImage = false;
    }
  }

  Future<void> _uploadProfileImage(XFile file) async {
    if (_vendor == null) {
      _showMessage('Vendor profile not loaded.', isError: true);
      return;
    }

    if (!mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final String? oldImageUrl = _vendor?.profileImageUrl;
      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Selected image is empty.');
      }

      final VendorModel updatedVendor = await _vendorRepository
          .uploadProfileImageBytes(bytes: bytes, fileName: file.name);

      if (!mounted) return;

      setState(() => _vendor = updatedVendor);

      await _vendorRepository.deleteOldProfileImage(oldImageUrl: oldImageUrl);

      imageCache.clear();
      imageCache.clearLiveImages();

      if (!mounted) return;

      _showMessage('Profile photo updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _removeProfileImage() async {
    final String? imageUrl = _vendor?.profileImageUrl;

    if (imageUrl == null || imageUrl.trim().isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppSettingsScope.translate(
            context,
            "vendor.remove_profile_photo.c710b044",
          ),
        ),
        content: Text(
          AppSettingsScope.translate(
            context,
            "vendor.are_you_sure_you_want_to_remove_your_profile_.4f705e8e",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              AppSettingsScope.translate(context, "vendor.cancel.19766ed6"),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _wine,
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppSettingsScope.translate(context, "vendor.remove.c3812fc4"),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final VendorModel updatedVendor = await _vendorRepository
          .removeProfileImage();

      if (!mounted) return;

      setState(() => _vendor = updatedVendor);

      imageCache.clear();
      imageCache.clearLiveImages();

      _showMessage('Profile photo removed.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showPhotoOptions() {
    final String? imageUrl = _vendor?.profileImageUrl;
    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.choose_from_gallery.763abbaa",
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _pickProfileImage();
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.remove_photo.f46512ab",
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _removeProfileImage();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updated = await _vendorRepository.updatePersonalDetails(
        name: _nameController.text.trim(),
        aboutMe: _aboutController.text.trim(),
        preferredContactLanguage: _preferredContactLanguage,
      );

      if (!mounted) return;

      setState(() {
        _vendor = updated;
        _nameController.text = updated.name;
        _aboutController.text = updated.aboutMe ?? '';
        _preferredContactLanguage = updated.preferredContactLanguage;
        _emailController.text = updated.email;
        _phoneController.text = updated.phone ?? '';
      });

      _showMessage(
        AppSettingsScope.translate(
          context,
          "vendor.profile_updated_successfully.6ccf8b7d",
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage(_cleanError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _cleanError(Object error) {
    final String message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFB00020) : _wine,
      ),
    );
  }

  Future<void> _openContactSettings(AccountSecurityAction action) async {
    if (_busy) return;

    await showAccountSecurityAction(context, action);

    if (!mounted) return;

    try {
      final vendor = await _vendorRepository.getMyVendor();

      if (!mounted || vendor == null) return;

      setState(() {
        _vendor = vendor;
        _emailController.text = vendor.email;
        _phoneController.text = vendor.phone ?? '';
      });
    } catch (_) {
      if (mounted) {
        _showMessage(
          AppSettingsScope.translate(
            context,
            "vendor.unable_to_refresh_contact_details.8254523a",
          ),
          isError: true,
        );
      }
    }
  }

  String _memberSince() {
    final date = _vendor?.createdAt?.toLocal();

    if (date == null) {
      return AppSettingsScope.translate(
        context,
        "vendor.not_available.67a926f7",
      );
    }

    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _contactDetails({
    required String title,
    required String value,
    required IconData icon,
    required AccountSecurityAction action,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _busy ? null : () => _openContactSettings(action),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE8E8ED)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(icon, size: 22, color: AppIconColors.standard),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666A7A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.trim().isEmpty
                          ? AppSettingsScope.translate(
                              context,
                              "vendor.not_added.2460c620",
                            )
                          : value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202638),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppIconColors.standard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: AppContentSkeleton(layout: SkeletonLayout.form),
      );
    }

    if (_errorMessage != null || _vendor == null) {
      return _buildErrorState();
    }

    final colors = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: AppShimmerRefreshIndicator(
        color: _wine,
        onRefresh: () async {
          if (!_busy) await _loadVendor();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFF0EDF0)),
                      boxShadow: [
                        BoxShadow(
                          color: _wine.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        IgnorePointer(
                          ignoring: _busy,
                          child: _buildProfilePhoto(),
                        ),
                        Column(
                          children: [
                            Text(
                              _nameController.text.trim().isEmpty
                                  ? AppSettingsScope.translate(
                                      context,
                                      "vendor.your_name.9cd26bee",
                                    )
                                  : _nameController.text.trim(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _wine,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _emailController.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF747783),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 1, color: Color(0xFFE8E8ED)),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _sectionTitle(
                            AppSettingsScope.translate(
                              context,
                              "vendor.personal_details.3a886778",
                            ),
                          ),
                        ),
                        TextFormField(
                          key: const Key('profile-name'),
                          controller: _nameController,
                          enabled: !_busy,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: AppSettingsScope.translate(
                              context,
                              "vendor.full_name.8e00cdf7",
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: AppIconColors.standard,
                            ),
                            filled: true,
                            fillColor: _background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8E8ED),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: _wine,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (value) => value?.trim().isEmpty != false
                              ? AppSettingsScope.translate(
                                  context,
                                  "vendor.please_enter_your_name.f9b561ae",
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('profile-about'),
                          controller: _aboutController,
                          enabled: !_busy,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 500,
                          decoration: InputDecoration(
                            labelText: AppSettingsScope.translate(
                              context,
                              "vendor.about_me_optional.af712642",
                            ),
                            hintText: AppSettingsScope.translate(
                              context,
                              "vendor.a_short_introduction_about_yourself.238360b7",
                            ),
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 55),
                              child: Icon(
                                Icons.notes_rounded,
                                color: AppIconColors.standard,
                              ),
                            ),
                            filled: true,
                            fillColor: _background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8E8ED),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: _wine,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (value) => (value?.runes.length ?? 0) > 500
                              ? AppSettingsScope.translate(
                                  context,
                                  "vendor.keep_your_introduction_within_500_characters.e104b9c1",
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'profile-language-$_preferredContactLanguage',
                          ),
                          initialValue: _preferredContactLanguage,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppSettingsScope.translate(
                              context,
                              "vendor.preferred_contact_language.ed9e328b",
                            ),
                            helperText: AppSettingsScope.translate(
                              context,
                              "vendor.for_customer_communication_this_does_not_chan.f49a5f35",
                            ),
                            helperMaxLines: 3,
                            prefixIcon: const Icon(
                              Icons.language_rounded,
                              color: AppIconColors.standard,
                            ),
                            filled: true,
                            fillColor: _background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8E8ED),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: _wine,
                                width: 1.5,
                              ),
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "vendor.no_preference.35f994b0",
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "vendor.english.ba118bf7",
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'ta',
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "vendor.tamil.135d78ac",
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'both',
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "vendor.tamil_english.2829e0d0",
                                ),
                              ),
                            ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _preferredContactLanguage = value,
                                ),
                        ),
                        const SizedBox(height: 26),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _sectionTitle(
                            AppSettingsScope.translate(
                              context,
                              "vendor.contact_details.3e84af61",
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppSettingsScope.translate(
                              context,
                              "vendor.tap_a_contact_detail_to_change_it_in_account_.e6a795d8",
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _contactDetails(
                          title: AppSettingsScope.translate(
                            context,
                            "vendor.email_address.09bf25ef",
                          ),
                          value: _emailController.text,
                          icon: Icons.mail_outline_rounded,
                          action: AccountSecurityAction.email,
                        ),
                        const SizedBox(height: 12),
                        _contactDetails(
                          title: AppSettingsScope.translate(
                            context,
                            "vendor.phone_number.72dba9ae",
                          ),
                          value: _phoneController.text,
                          icon: Icons.phone_outlined,
                          action: AccountSecurityAction.phone,
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const SizedBox(
                            width: 28,
                            child: Icon(
                              Icons.event_available_outlined,
                              size: 22,
                              color: AppIconColors.standard,
                            ),
                          ),
                          title: Text(
                            AppSettingsScope.translate(
                              context,
                              "vendor.member_since.f4d3b821",
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666A7A),
                            ),
                          ),
                          subtitle: Text(
                            _memberSince(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF202638),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _busy ? null : _saveProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: _wine,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _wine.withValues(
                                alpha: 0.55,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: AppShimmerIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "vendor.save_changes.35322b5b",
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    final String? imageUrl = _vendor?.profileImageUrl;
    final String name = _vendor?.name.trim() ?? '';

    final String initial = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : 'V';

    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return Center(
      child: GestureDetector(
        onTap: _busy ? null : _showPhotoOptions,
        child: SizedBox(
          width: 112,
          height: 118,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: hasImage
                      ? Image.network(
                          imageUrl,
                          key: ValueKey(imageUrl),
                          width: 98,
                          height: 98,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildInitialAvatar(initial),
                        )
                      : _buildInitialAvatar(initial),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _wine,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: _isUploadingImage || _isPickingProfileImage
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: AppShimmerIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return CircleAvatar(
      radius: 58,
      backgroundColor: const Color(0xFFF4E5E9),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: _wine,
        ),
      ),
    );
  }

  Widget _buildErrorState({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 52,
              color: AppIconColors.standard,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? _errorMessage ?? 'Unable to load profile.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loadVendor,
              style: FilledButton.styleFrom(
                backgroundColor: _wine,
                foregroundColor: Colors.white,
              ),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.try_again.df0fe9e0",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VendorPageScaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          _profileTitle,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _background,
        foregroundColor: Colors.black,
        iconTheme: const IconThemeData(color: AppIconColors.standard),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }
}
