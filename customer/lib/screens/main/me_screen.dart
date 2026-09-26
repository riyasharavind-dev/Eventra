import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({
    super.key,
  });

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final ImagePicker _imagePicker = ImagePicker();

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color primaryRed =
      Color(0xFF9F0101);

  static const Color background =
      Color(0xFFF8F8F8);

  static const Color textDark =
      Color(0xFF202020);

  static const Color textGrey =
      Color(0xFF777777);

  static const Color lightRed =
      Color(0xFFFFEEEE);

  // ===========================================================================
  // PROFILE DATA
  // ===========================================================================

  String userName = '';
  String phoneNumber = '';
  String email = '';
  String? avatarUrl;

  String selectedLanguage = 'English';

  bool notificationsEnabled = true;

  bool isLoading = true;
  bool isSaving = false;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _loadProfile();
    });
  }

  // ===========================================================================
  // LOAD PROFILE
  // ===========================================================================

  Future<void> _loadProfile() async {
    try {
      final User? user =
          _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        return;
      }

      final String userId = user.id;

      debugPrint(
        '==============================',
      );
      debugPrint(
        'LOADING EVENTRA PROFILE',
      );
      debugPrint(
        'USER ID: $userId',
      );
      debugPrint(
        '==============================',
      );

      Map<String, dynamic>? userData;
      Map<String, dynamic>? customerData;

      // -----------------------------------------------------------------------
      // USERS
      // -----------------------------------------------------------------------

      try {
        final dynamic result =
            await _supabase
                .from('users')
                .select('name, email')
                .eq('id', userId)
                .maybeSingle();

        if (result != null) {
          userData =
              Map<String, dynamic>.from(result);
        }
      } catch (e) {
        debugPrint(
          'USERS LOAD ERROR: $e',
        );
      }

      // -----------------------------------------------------------------------
      // CUSTOMERS
      // -----------------------------------------------------------------------

      try {
        final dynamic result =
            await _supabase
                .from('customers')
                .select(
                  'id, name, email, phone, avatar_url',
                )
                .eq('id', userId)
                .maybeSingle();

        if (result != null) {
          customerData =
              Map<String, dynamic>.from(result);
        }
      } catch (e) {
        debugPrint(
          'CUSTOMERS LOAD ERROR: $e',
        );
      }

      if (!mounted) return;

      setState(() {
        userName =
            userData?['name']?.toString() ??
                customerData?['name']?.toString() ??
                '';

        email =
            userData?['email']?.toString() ??
                customerData?['email']?.toString() ??
                user.email ??
                '';

        phoneNumber =
            customerData?['phone']?.toString() ??
                '';

        avatarUrl =
            customerData?['avatar_url']?.toString();

        isLoading = false;
      });

      debugPrint(
        'PROFILE NAME: $userName',
      );
      debugPrint(
        'PROFILE EMAIL: $email',
      );
      debugPrint(
        'PROFILE PHONE: $phoneNumber',
      );
      debugPrint(
        'PROFILE IMAGE: $avatarUrl',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'PROFILE LOAD ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load profile',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // PHOTO PERMISSION
  // ===========================================================================

  Future<bool> _requestPhotoPermission() async {
    try {
      if (Platform.isAndroid) {
        PermissionStatus status =
            await Permission.photos.status;

        debugPrint(
          'PHOTO PERMISSION STATUS: $status',
        );

        if (status.isGranted ||
            status.isLimited) {
          return true;
        }

        if (status.isDenied) {
          status =
              await Permission.photos.request();

          debugPrint(
            'PHOTO PERMISSION RESULT: $status',
          );

          if (status.isGranted ||
              status.isLimited) {
            return true;
          }
        }

        if (status.isPermanentlyDenied) {
          await _showPermissionSettingsDialog();

          return false;
        }

        // Older Android fallback.
        final PermissionStatus
            storageStatus =
            await Permission.storage.status;

        if (storageStatus.isGranted) {
          return true;
        }

        if (storageStatus.isDenied) {
          final PermissionStatus requested =
              await Permission.storage.request();

          if (requested.isGranted) {
            return true;
          }
        }

        if (storageStatus.isPermanentlyDenied) {
          await _showPermissionSettingsDialog();

          return false;
        }

        return false;
      }

      if (Platform.isIOS) {
        PermissionStatus status =
            await Permission.photos.status;

        if (status.isGranted ||
            status.isLimited) {
          return true;
        }

        if (status.isDenied) {
          status =
              await Permission.photos.request();

          if (status.isGranted ||
              status.isLimited) {
            return true;
          }
        }

        if (status.isPermanentlyDenied) {
          await _showPermissionSettingsDialog();

          return false;
        }

        return false;
      }

      return true;
    } catch (e) {
      debugPrint(
        'PERMISSION ERROR: $e',
      );

      return false;
    }
  }

  // ===========================================================================
  // PERMISSION SETTINGS
  // ===========================================================================

  Future<void>
      _showPermissionSettingsDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: const Text(
            'Photo Permission',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Eventra needs photo access to '
            'change your profile picture.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(
                  dialogContext,
                ).pop();

                await openAppSettings();
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Open Settings',
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // PICK PROFILE IMAGE
  // ===========================================================================

  Future<void> _pickProfileImage() async {
    if (isSaving) return;

    try {
      final bool permissionGranted =
          await _requestPhotoPermission();

      if (!permissionGranted) {
        if (!mounted) return;

        _showMessage(
          'Photo access permission is required',
          isError: true,
        );

        return;
      }

      if (!mounted) return;

      final XFile? selectedImage =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (selectedImage == null) {
        debugPrint(
          'IMAGE PICK CANCELLED',
        );

        return;
      }

      debugPrint(
        'IMAGE SELECTED: ${selectedImage.path}',
      );

      final File imageFile =
          File(selectedImage.path);

      await _uploadProfileImage(
        imageFile,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'IMAGE PICK ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to select image',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // UPLOAD PROFILE IMAGE
  // ===========================================================================

  Future<void> _uploadProfileImage(
    File imageFile,
  ) async {
    if (isSaving) return;

    try {
      final User? user =
          _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'No authenticated user found',
        );
      }

      if (!await imageFile.exists()) {
        throw Exception(
          'Selected image file does not exist',
        );
      }

      if (!mounted) return;

      setState(() {
        isSaving = true;
      });

      final String userId = user.id;

      // -----------------------------------------------------------------------
      // STORAGE PATH
      // -----------------------------------------------------------------------

      final String filePath =
          'customers/$userId/profile.jpg';

      debugPrint(
        '========================================',
      );
      debugPrint(
        'EVENTRA PROFILE IMAGE UPLOAD',
      );
      debugPrint(
        '========================================',
      );
      debugPrint(
        'USER ID: $userId',
      );
      debugPrint(
        'BUCKET: profile-images',
      );
      debugPrint(
        'PATH: $filePath',
      );

      // -----------------------------------------------------------------------
      // UPLOAD
      // -----------------------------------------------------------------------

      await _supabase.storage
          .from('profile-images')
          .upload(
        filePath,
        imageFile,
        fileOptions:
            const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
          cacheControl: '3600',
        ),
      );

      debugPrint(
        'STORAGE UPLOAD SUCCESS',
      );

      // -----------------------------------------------------------------------
      // PUBLIC URL
      // -----------------------------------------------------------------------

      final String baseUrl =
          _supabase.storage
              .from('profile-images')
              .getPublicUrl(
                filePath,
              );

      final String publicUrl =
          '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      debugPrint(
        'PUBLIC URL: $publicUrl',
      );

      // -----------------------------------------------------------------------
      // CHECK CUSTOMER ROW
      // -----------------------------------------------------------------------

      final dynamic existingCustomer =
          await _supabase
              .from('customers')
              .select('id')
              .eq('id', userId)
              .maybeSingle();

      // -----------------------------------------------------------------------
      // SAVE AVATAR URL
      // -----------------------------------------------------------------------

      if (existingCustomer != null) {
        await _supabase
            .from('customers')
            .update({
          'avatar_url': publicUrl,
          'updated_at':
              DateTime.now()
                  .toIso8601String(),
        }).eq(
          'id',
          userId,
        );
      } else {
        await _supabase
            .from('customers')
            .insert({
          'id': userId,
          'name': userName.isEmpty
              ? 'User'
              : userName,
          'email': email.isEmpty
              ? (user.email ?? '')
              : email,
          'phone':
              phoneNumber.isEmpty
                  ? null
                  : phoneNumber,
          'avatar_url': publicUrl,
          'updated_at':
              DateTime.now()
                  .toIso8601String(),
        });
      }

      debugPrint(
        'CUSTOMERS TABLE UPDATE SUCCESS',
      );

      // -----------------------------------------------------------------------
      // VERIFY DATABASE
      // -----------------------------------------------------------------------

      final dynamic verify =
          await _supabase
              .from('customers')
              .select('avatar_url')
              .eq('id', userId)
              .maybeSingle();

      debugPrint(
        'DB AVATAR URL: ${verify?['avatar_url']}',
      );

      // -----------------------------------------------------------------------
      // UPDATE UI
      // -----------------------------------------------------------------------

      if (!mounted) return;

      setState(() {
        avatarUrl = publicUrl;
        isSaving = false;
      });

      _showMessage(
        'Profile photo updated successfully',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'PROFILE IMAGE UPLOAD FAILED',
      );

      debugPrint(
        'ERROR: $e',
      );

      debugPrint(
        'STACK TRACE: $stackTrace',
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        _getSupabaseErrorMessage(e),
        isError: true,
      );
    }
  }

  // ===========================================================================
  // SUPABASE ERROR MESSAGE
  // ===========================================================================

  String _getSupabaseErrorMessage(
    Object error,
  ) {
    final String message =
        error.toString();

    if (message.contains(
      'row-level security',
    )) {
      return 'Supabase permission denied. Check RLS policy.';
    }

    if (message.contains(
      'Bucket not found',
    )) {
      return 'profile-images bucket not found.';
    }

    if (message.contains(
      'Unauthorized',
    )) {
      return 'Storage permission denied.';
    }

    if (message.contains(
      'duplicate key',
    )) {
      return 'Customer profile already exists.';
    }

    return 'Profile image upload failed.';
  }

  // ===========================================================================
  // EDIT PROFILE
  // ===========================================================================

  Future<void> _showEditProfile() async {
    if (isSaving) return;

    final EditProfileResult? result =
        await showModalBottomSheet<
            EditProfileResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor:
          Colors.black.withValues(
        alpha: 0.45,
      ),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return EditProfileSheet(
          initialName: userName,
          initialPhone: phoneNumber,
          email: email,
          avatarUrl: avatarUrl,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.changePhoto) {
      await Future<void>.delayed(
        const Duration(
          milliseconds: 350,
        ),
      );

      if (!mounted) return;

      await _pickProfileImage();

      return;
    }

    if (result.saved) {
      await _updateProfile(
        name: result.name,
        phone: result.phone,
      );
    }
  }

  // ===========================================================================
  // UPDATE PROFILE
  // ===========================================================================

  Future<bool> _updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      final User? user =
          _supabase.auth.currentUser;

      if (user == null) {
        _showMessage(
          'User is not logged in',
          isError: true,
        );

        return false;
      }

      if (name.trim().isEmpty) {
        _showMessage(
          'Please enter your name',
          isError: true,
        );

        return false;
      }

      if (!mounted) return false;

      setState(() {
        isSaving = true;
      });

      final String userId = user.id;

      // -----------------------------------------------------------------------
      // USERS
      // -----------------------------------------------------------------------

      await _supabase
          .from('users')
          .update({
        'name': name.trim(),
      }).eq(
        'id',
        userId,
      );

      debugPrint(
        'USERS TABLE UPDATED',
      );

      // -----------------------------------------------------------------------
      // CUSTOMERS
      // -----------------------------------------------------------------------

      final dynamic existingCustomer =
          await _supabase
              .from('customers')
              .select('id')
              .eq('id', userId)
              .maybeSingle();

      if (existingCustomer != null) {
        await _supabase
            .from('customers')
            .update({
          'name': name.trim(),
          'phone':
              phone.trim().isEmpty
                  ? null
                  : phone.trim(),
          'updated_at':
              DateTime.now()
                  .toIso8601String(),
        }).eq(
          'id',
          userId,
        );
      } else {
        await _supabase
            .from('customers')
            .insert({
          'id': userId,
          'name': name.trim(),
          'email': email.isEmpty
              ? (user.email ?? '')
              : email,
          'phone':
              phone.trim().isEmpty
                  ? null
                  : phone.trim(),
          'avatar_url': avatarUrl,
          'updated_at':
              DateTime.now()
                  .toIso8601String(),
        });
      }

      debugPrint(
        'CUSTOMERS TABLE UPDATED',
      );

      if (!mounted) return true;

      setState(() {
        userName = name.trim();
        phoneNumber = phone.trim();
        isSaving = false;
      });

      _showMessage(
        'Profile updated successfully',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        'PROFILE UPDATE ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) return false;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        _getSupabaseErrorMessage(e),
        isError: true,
      );

      return false;
    }
  }

  // ===========================================================================
  // LANGUAGE
  // ===========================================================================

  Future<void> _showLanguageSelector() async {
    const List<String> languages = [
      'English',
      'Tamil',
      'Tanglish',
      'Hindi',
      'Malayalam',
    ];

    final String? result =
        await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              ...languages.map(
                (language) {
                  final bool selected =
                      selectedLanguage ==
                          language;

                  return ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    title: Text(
                      language,
                      style: TextStyle(
                        fontWeight:
                            selected
                                ? FontWeight
                                    .w600
                                : FontWeight
                                    .w400,
                      ),
                    ),
                    trailing: Icon(
                      selected
                          ? Icons
                              .check_circle
                          : Icons
                              .radio_button_unchecked,
                      color: selected
                          ? primaryRed
                          : Colors.grey,
                    ),
                    onTap: () {
                      Navigator.of(
                        sheetContext,
                      ).pop(language);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      selectedLanguage = result;
    });

    _showMessage(
      'Language changed to $result',
    );
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  Future<void>
      _showNotificationSettings() async {
    final bool? result =
        await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        bool localValue =
            notificationsEnabled;

        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            return Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                30,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Align(
                    alignment:
                        Alignment.centerLeft,
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  SwitchListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    title: const Text(
                      'Push Notifications',
                    ),
                    subtitle: const Text(
                      'Receive booking and event updates',
                    ),
                    value: localValue,
                    activeThumbColor:
                        primaryRed,
                    onChanged: (value) {
                      setSheetState(() {
                        localValue = value;
                      });
                    },
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          sheetContext,
                        ).pop(localValue);
                      },
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            primaryRed,
                        foregroundColor:
                            Colors.white,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Done',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      notificationsEnabled = result;
    });

    _showMessage(
      result
          ? 'Notifications enabled'
          : 'Notifications disabled',
    );
  }

  // ===========================================================================
  // DUMMY PAGE
  // ===========================================================================

  void _openDummyPage(
    String title,
    IconData icon,
    String description,
  ) {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DummyPage(
          title: title,
          icon: icon,
          description: description,
        ),
      ),
    );
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  Future<void> _showLogoutDialog() async {
    final bool? shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: const Text(
            'Logout?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout from Eventra?',
          ),
          actions: [
            // ---------------------------------------------------------------
            // CANCEL
            // ---------------------------------------------------------------

            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),

            // ---------------------------------------------------------------
            // LOGOUT
            // ---------------------------------------------------------------

            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryRed,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      // ================================================================
      // SIGN OUT FROM SUPABASE
      // ================================================================

      await _supabase.auth.signOut();

      if (!mounted) {
        return;
      }

      // ================================================================
      // IMPORTANT
      // ================================================================
      //
      // We directly remove the authenticated navigation stack
      // and open LoginScreen.
      //
      // This prevents CustomerMainScreen / IndexedStack from
      // remaining visible after logout.
      // ================================================================

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'LOGOUT ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to logout',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!mounted) return;

      final ScaffoldMessengerState?
          messenger =
          ScaffoldMessenger.maybeOf(
        context,
      );

      if (messenger == null) return;

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          backgroundColor:
              isError
                  ? Colors.red.shade700
                  : primaryRed,
          duration:
              const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      );
    });
  }

  // ===========================================================================
  // MENU ITEM
  // ===========================================================================

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
    Widget? trailing,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 15,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color: lightRed,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: primaryRed,
                    size: 21,
                  ),
                ),
                const SizedBox(
                  width: 14,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            const TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 12,
                            color: textGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons
                          .chevron_right_rounded,
                      color: Colors.grey,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),
      ],
    );
  }

  // ===========================================================================
  // SECTION
  // ===========================================================================

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        6,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(
              left: 4,
              bottom: 8,
            ),
            child: Text(
              title,
              style:
                  const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w700,
                color: textDark,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(
                    alpha: 0.025,
                  ),
                  blurRadius: 8,
                  offset:
                      const Offset(0, 3),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(
          child:
              CircularProgressIndicator(
            color: primaryRed,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryRed,
          onRefresh: _loadProfile,
          child: CustomScrollView(
            physics:
                const BouncingScrollPhysics(),
            slivers: [
              // =================================================================
              // HEADER
              // =================================================================

              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    8,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Me',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight:
                                FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                      ),
                      Container(
                        width: 46,
                        height: 46,
                        decoration:
                            BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withValues(
                                alpha: 0.04,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () {
                            _openDummyPage(
                              'Settings',
                              Icons
                                  .settings_outlined,
                              'Account settings will be available here.',
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .settings_outlined,
                            size: 22,
                            color: textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================================
              // PROFILE CARD
              // =================================================================

              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    10,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    decoration:
                        BoxDecoration(
                      gradient:
                          const LinearGradient(
                        begin:
                            Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                        colors: [
                          Color(0xFF9F0101),
                          Color(0xFFC66D6D),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors
                              .black
                              .withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 18,
                          offset:
                              const Offset(
                            0,
                            8,
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // ===================================================
                            // PROFILE IMAGE
                            // ===================================================

                            GestureDetector(
                              onTap: isSaving
                                  ? null
                                  : _pickProfileImage,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.white,
                                      shape:
                                          BoxShape.circle,
                                      border:
                                          Border.all(
                                        color:
                                            Colors.white,
                                        width: 3,
                                      ),
                                      image:
                                          avatarUrl !=
                                                      null &&
                                                  avatarUrl!
                                                      .isNotEmpty
                                              ? DecorationImage(
                                                  image:
                                                      NetworkImage(
                                                    avatarUrl!,
                                                  ),
                                                  fit:
                                                      BoxFit.cover,
                                                )
                                              : null,
                                    ),
                                    child:
                                        avatarUrl ==
                                                    null ||
                                                avatarUrl!
                                                    .isEmpty
                                            ? const Icon(
                                                Icons.person,
                                                size:
                                                    40,
                                                color:
                                                    primaryRed,
                                              )
                                            : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child:
                                        Container(
                                      width: 25,
                                      height: 25,
                                      decoration:
                                          const BoxDecoration(
                                        color:
                                            Colors.white,
                                        shape:
                                            BoxShape.circle,
                                      ),
                                      child:
                                          const Icon(
                                        Icons
                                            .camera_alt_outlined,
                                        size: 14,
                                        color:
                                            primaryRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              width: 16,
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    userName.isEmpty
                                        ? 'User'
                                        : userName,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                      fontSize: 19,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    phoneNumber.isEmpty
                                        ? 'Phone number not added'
                                        : phoneNumber,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 3,
                                  ),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child:
                              OutlinedButton(
                            onPressed:
                                isSaving
                                    ? null
                                    : _showEditProfile,
                            style:
                                OutlinedButton.styleFrom(
                              foregroundColor:
                                  Colors.white,
                              side:
                                  const BorderSide(
                                color:
                                    Colors.white,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  13,
                                ),
                              ),
                            ),
                            child:
                                const Text(
                              'Edit Profile',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // =================================================================
              // MY ACTIVITY
              // =================================================================

              SliverToBoxAdapter(
                child: _buildSection(
                  title: 'My Activity',
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons
                            .calendar_month_outlined,
                        title: 'My Bookings',
                        subtitle:
                            'View and manage your bookings',
                        onTap: () {
                          _openDummyPage(
                            'My Bookings',
                            Icons
                                .calendar_month_outlined,
                            'Your bookings will appear here.',
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons
                            .celebration_outlined,
                        title: 'My Events',
                        subtitle:
                            'Manage your upcoming events',
                        onTap: () {
                          _openDummyPage(
                            'My Events',
                            Icons
                                .celebration_outlined,
                            'Your events will appear here.',
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon:
                            Icons.favorite_border,
                        title: 'Saved Vendors',
                        subtitle:
                            'Vendors you saved for later',
                        onTap: () {
                          _openDummyPage(
                            'Saved Vendors',
                            Icons.favorite_border,
                            'Your saved vendors will appear here.',
                          );
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================================
              // ACCOUNT
              // =================================================================

              SliverToBoxAdapter(
                child: _buildSection(
                  title: 'Account',
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons
                            .location_on_outlined,
                        title: 'My Addresses',
                        subtitle:
                            'Manage your event locations',
                        onTap: () {
                          _openDummyPage(
                            'My Addresses',
                            Icons
                                .location_on_outlined,
                            'Your saved addresses will appear here.',
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons
                            .notifications_none_rounded,
                        title: 'Notifications',
                        subtitle:
                            notificationsEnabled
                                ? 'Notifications are enabled'
                                : 'Notifications are disabled',
                        onTap:
                            _showNotificationSettings,
                      ),
                      _buildMenuItem(
                        icon:
                            Icons.language_outlined,
                        title: 'Language',
                        subtitle:
                            selectedLanguage,
                        onTap:
                            _showLanguageSelector,
                      ),
                      _buildMenuItem(
                        icon: Icons
                            .help_outline_rounded,
                        title: 'Help & Support',
                        subtitle:
                            'Get help with Eventra',
                        onTap: () {
                          _openDummyPage(
                            'Help & Support',
                            Icons
                                .help_outline_rounded,
                            'Support options will appear here.',
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons
                            .security_outlined,
                        title:
                            'Privacy & Security',
                        subtitle:
                            'Manage your account privacy',
                        onTap: () {
                          _openDummyPage(
                            'Privacy & Security',
                            Icons
                                .security_outlined,
                            'Privacy and security settings will appear here.',
                          );
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================================
              // LOGOUT
              // =================================================================

              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    4,
                  ),
                  child: Container(
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: InkWell(
                      onTap:
                          isSaving
                              ? null
                              : _showLogoutDialog,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 17,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .logout_rounded,
                              color: Colors.red,
                            ),
                            SizedBox(
                              width: 14,
                            ),
                            Text(
                              'Log Out',
                              style:
                                  TextStyle(
                                color:
                                    Colors.red,
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // =================================================================
              // VERSION
              // =================================================================

              const SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    30,
                  ),
                  child: Center(
                    child: Text(
                      'Eventra • Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: textGrey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EDIT PROFILE RESULT
// =============================================================================

class EditProfileResult {
  final bool saved;
  final bool changePhoto;
  final String name;
  final String phone;

  const EditProfileResult({
    this.saved = false,
    this.changePhoto = false,
    this.name = '',
    this.phone = '',
  });
}

// =============================================================================
// EDIT PROFILE SHEET
// =============================================================================

class EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String email;
  final String? avatarUrl;

  const EditProfileSheet({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.email,
    required this.avatarUrl,
  });

  @override
  State<EditProfileSheet> createState() =>
      _EditProfileSheetState();
}

class _EditProfileSheetState
    extends State<EditProfileSheet> {
  late final TextEditingController
      _nameController;

  late final TextEditingController
      _phoneController;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text: widget.initialName,
    );

    _phoneController =
        TextEditingController(
      text: widget.initialPhone,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // TEXT FIELD
  // ===========================================================================

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    const Color primaryRed =
        Color(0xFF9F0101);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction:
          TextInputAction.next,
      decoration:
          InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: primaryRed,
        ),
        filled: true,
        fillColor:
            const Color(0xFFF7F7F7),
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              BorderSide.none,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              BorderSide.none,
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color: primaryRed,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    const Color primaryRed =
        Color(0xFF9F0101);

    const Color textDark =
        Color(0xFF202020);

    const Color textGrey =
        Color(0xFF777777);

    const Color lightRed =
        Color(0xFFFFEEEE);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom:
            MediaQuery.of(context)
                .viewInsets
                .bottom +
                20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // =================================================================
            // HANDLE
            // =================================================================

            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade300,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            // =================================================================
            // TITLE
            // =================================================================

            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 23,
                fontWeight:
                    FontWeight.bold,
                color: textDark,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            // =================================================================
            // PROFILE IMAGE
            // =================================================================

            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(
                    context,
                  ).pop(
                    const EditProfileResult(
                      changePhoto: true,
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration:
                          BoxDecoration(
                        color: lightRed,
                        shape:
                            BoxShape.circle,
                        image:
                            widget.avatarUrl !=
                                        null &&
                                    widget.avatarUrl!
                                        .isNotEmpty
                                ? DecorationImage(
                                    image:
                                        NetworkImage(
                                      widget.avatarUrl!,
                                    ),
                                    fit:
                                        BoxFit.cover,
                                  )
                                : null,
                      ),
                      child:
                          widget.avatarUrl ==
                                      null ||
                                  widget.avatarUrl!
                                      .isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 52,
                                  color:
                                      primaryRed,
                                )
                              : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration:
                            const BoxDecoration(
                          color: primaryRed,
                          shape:
                              BoxShape.circle,
                        ),
                        child:
                            const Icon(
                          Icons
                              .camera_alt_outlined,
                          color:
                              Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Center(
              child: Text(
                'Tap photo to change',
                style: TextStyle(
                  fontSize: 12,
                  color: textGrey,
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            // =================================================================
            // NAME
            // =================================================================

            _buildTextField(
              controller:
                  _nameController,
              label: 'Full Name',
              icon:
                  Icons.person_outline,
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================================
            // PHONE
            // =================================================================

            _buildTextField(
              controller:
                  _phoneController,
              label: 'Phone Number',
              icon:
                  Icons.phone_outlined,
              keyboardType:
                  TextInputType.phone,
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================================
            // EMAIL
            // =================================================================

            TextField(
              enabled: false,
              controller:
                  TextEditingController(
                text: widget.email,
              ),
              decoration:
                  InputDecoration(
                labelText: 'Email',
                prefixIcon:
                    const Icon(
                  Icons.email_outlined,
                  color: primaryRed,
                ),
                filled: true,
                fillColor:
                    const Color(
                  0xFFF7F7F7,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // =================================================================
            // SAVE
            // =================================================================

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final String name =
                      _nameController.text
                          .trim();

                  final String phone =
                      _phoneController.text
                          .trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter your name',
                        ),
                        backgroundColor:
                            primaryRed,
                      ),
                    );

                    return;
                  }

                  Navigator.of(
                    context,
                  ).pop(
                    EditProfileResult(
                      saved: true,
                      name: name,
                      phone: phone,
                    ),
                  );
                },
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primaryRed,
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 8,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DUMMY PAGE
// =============================================================================

class _DummyPage
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const _DummyPage({
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    const Color primaryRed =
        Color(0xFF9F0101);

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: Text(title),
        backgroundColor:
            Colors.white,
        foregroundColor:
            Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFFEEEE,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    25,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 45,
                  color: primaryRed,
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              Text(
                title,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                description,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}