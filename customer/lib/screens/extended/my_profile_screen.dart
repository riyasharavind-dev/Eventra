import '../../services/app_live_data.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/auth_model.dart';
import '../../repositories/profile_repository.dart';
import '../../models/edit_profile_result.dart';
import '../../widgets/profile/edit_profile_sheet.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with LiveDataState<MyProfileScreen> {
  @override
  Set<String> get liveDatasets => {'own:customers', 'own:users'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _loadProfile();
  }

  // =========================================================
  // REPOSITORY
  // =========================================================

  final ProfileRepository _profileRepository = ProfileRepository();

  final ImagePicker _imagePicker = ImagePicker();

  // =========================================================
  // COLORS
  // =========================================================

  static const Color primaryRed = Color(0xFF80152C);

  static const Color background = Color(0xFFF8F8F8);

  static const Color textDark = Color(0xFF202020);

  static const Color textGrey = Color(0xFF777777);

  static const Color lightRed = Color(0xFFFFEEEE);

  // =========================================================
  // STATE
  // =========================================================

  AuthModel? _user;

  bool _isLoading = true;
  bool _isSaving = false;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  // =========================================================
  // LOAD PROFILE
  // =========================================================

  Future<void> _loadProfile() async {
    try {
      final AuthModel? user = await _profileRepository.getProfile();

      if (!mounted) return;

      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('PROFILE LOAD ERROR: $e');

      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to load profile', isError: true);
    }
  }

  // =========================================================
  // EDIT PROFILE
  // =========================================================

  Future<void> _showEditProfile() async {
    if (_user == null || _isSaving) {
      return;
    }

    final EditProfileResult? result =
        await showModalBottomSheet<EditProfileResult>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (_) {
            return EditProfileSheet(
              initialName: _user!.name,
              initialPhone: _user!.phone ?? '',
              email: _user!.email,
            );
          },
        );

    if (!mounted || result == null) {
      return;
    }

    if (!result.saved) {
      return;
    }

    await _updateProfile(name: result.name, phone: result.phone);
  }

  // =========================================================
  // UPDATE PROFILE
  // =========================================================

  Future<void> _updateProfile({
    required String name,
    required String phone,
  }) async {
    if (_isSaving) return;

    try {
      setState(() {
        _isSaving = true;
      });

      final AuthModel? updatedUser = await _profileRepository.updateProfile(
        name: name,
        phone: phone,
      );

      if (!mounted) return;

      setState(() {
        _user = updatedUser;
        _isSaving = false;
      });

      _showMessage('Profile updated successfully');
    } catch (e, stackTrace) {
      debugPrint('PROFILE UPDATE ERROR: $e');

      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Unable to update profile', isError: true);
    }
  }

  // =========================================================
  // PICK PROFILE IMAGE
  // =========================================================

  Future<void> _pickProfileImage() async {
    if (_isSaving) return;

    try {
      final XFile? selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (selectedImage == null) {
        return;
      }

      final File imageFile = File(selectedImage.path);

      setState(() {
        _isSaving = true;
      });

      final AuthModel? updatedUser = await _profileRepository
          .updateProfileImage(imageFile);

      if (!mounted) return;

      setState(() {
        _user = updatedUser;
        _isSaving = false;
      });

      _showMessage('Profile photo updated successfully');
    } catch (e, stackTrace) {
      debugPrint('PROFILE IMAGE ERROR: $e');

      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Unable to update profile photo', isError: true);
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
        context,
      );

      if (messenger == null) return;

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: isError ? Colors.red.shade700 : primaryRed,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
  }

  // =========================================================
  // PROFILE IMAGE
  // =========================================================

  Widget _buildProfileImage() {
    final String? avatarUrl = _user?.avatarUrl;

    return GestureDetector(
      onTap: _isSaving ? null : _pickProfileImage,
      child: Stack(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              image: avatarUrl != null && avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(Icons.person, size: 48, color: primaryRed)
                : null,
          ),

          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 16,
                color: primaryRed,
              ),
            ),
          ),

          if (_isSaving)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 25,
                    height: 25,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(color: primaryRed)),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: ElevatedButton(
            onPressed: _loadProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(title: const Text('My Profile')),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryRed,
          onRefresh: _loadProfile,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 128),
            children: [
              // =====================================================
              // HEADER
              // =====================================================

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Personal information',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // =====================================================
              // PROFILE CARD
              // =====================================================
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF80152C), Color(0xFFAC4665)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // PROFILE PHOTO

                    _buildProfileImage(),

                    const SizedBox(height: 16),

                    // NAME
                    Text(
                      _user!.name.isEmpty ? 'User' : _user!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // PHONE
                    Text(
                      (_user!.phone == null || _user!.phone!.isEmpty)
                          ? 'Phone number not added'
                          : _user!.phone!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // EMAIL
                    Text(
                      _user!.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // EDIT PROFILE
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _showEditProfile,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =====================================================
              // PROFILE INFORMATION
              // =====================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.person_outline,
                      title: 'Name',
                      value: _user!.name,
                    ),

                    const Divider(height: 28),

                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: (_user!.phone == null || _user!.phone!.isEmpty)
                          ? 'Not added'
                          : _user!.phone!,
                    ),

                    const Divider(height: 28),

                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: _user!.email,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // INFO ROW
  // =========================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: lightRed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryRed, size: 21),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: textGrey),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Not added' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
