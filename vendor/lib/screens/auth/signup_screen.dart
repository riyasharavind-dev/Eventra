import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/services.dart';

import '../../main.dart';
import '../../utils/auth_error_message.dart';

import 'package:flutter/material.dart';

import '../../repositories/auth_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthRepository _authRepository = AuthRepository();

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const Color _wine = Color(0xFF80152C);
  static const Color _background = Color(0xFFF8F8FA);
  static const Color _textColor = Color(0xFF17171B);
  static const Color _hintColor = Color(0xFF85838E);
  static const Color _borderColor = Color(0xFFE5E5EB);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ==========================================
  // INPUT DECORATION
  // ==========================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
      prefixIcon: Icon(icon, size: 21, color: AppIconColors.standard),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _wine, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }

  // ==========================================
  // SIGN UP
  // ==========================================

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authRepository.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: '+91${_phoneController.text.trim()}',
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.user != null) {
        if (response.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.account_created_please_verify_your_email_befo.3389097e",
                ),
              ),
            ),
          );

          Navigator.pop(context);
          return;
        }

        // Replace the pushed signup route; the auth gate validates the vendor role.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VendorEntryScreen()),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettingsScope.translate(
              context,
              "vendor.unable_to_create_account_please_try_again.51be557a",
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _wine),
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ==================================
                      // TITLE
                      // ==================================
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.create_account.798ca2ce",
                        ),
                        style: TextStyle(
                          fontSize: 29,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: _textColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.join_eventor_and_start_managing_your_business.1d6a7d2a",
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: _hintColor,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================
                      // NAME
                      // ==================================
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.full_name.f13a64ba",
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          hint: AppSettingsScope.translate(
                            context,
                            "vendor.enter_your_name.0421de12",
                          ),
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.please_enter_your_name.a286aa34",
                            );
                          }

                          if (value.trim().length < 2) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.name_must_be_at_least_2_characters.9654ce02",
                            );
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.phone_number.306f1bb2",
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.telephoneNumberNational,
                        ],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration:
                            _inputDecoration(
                              hint: '9876543210',
                              icon: Icons.phone_outlined,
                            ).copyWith(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 16, right: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 21,
                                      color: AppIconColors.standard,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      '+91',
                                      style: TextStyle(
                                        color: _textColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.please_enter_your_phone_number.f3ebc0cc",
                            );
                          }
                          if (!RegExp(r'^[6-9][0-9]{9}$')
                              .hasMatch(value.trim())) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.please_enter_a_valid_10_digit_indian_mobile_n.a201a4dc",
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // ==================================
                      // EMAIL
                      // ==================================
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.email_address.f2488fd4",
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: _inputDecoration(
                          hint: AppSettingsScope.translate(
                            context,
                            "vendor.enter_your_email.2837f6fa",
                          ),
                          icon: Icons.mail_outline_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.please_enter_your_email.15edb313",
                            );
                          }

                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.please_enter_a_valid_email.845babfe",
                            );
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // ==================================
                      // PASSWORD
                      // ==================================
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.password.e7cf3ef4",
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          hint: AppSettingsScope.translate(
                            context,
                            "vendor.create_a_password.4defceba",
                          ),
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppIconColors.standard,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.please_enter_a_password.617676ea",
                            );
                          }

                          if (value.length < 6) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.password_must_be_at_least_6_characters.2005290d",
                            );
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // ==================================
                      // CONFIRM PASSWORD
                      // ==================================
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.confirm_password.5ac265f3",
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _signUp(),
                        decoration: _inputDecoration(
                          hint: AppSettingsScope.translate(
                            context,
                            "vendor.re_enter_your_password.210dfc7e",
                          ),
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppIconColors.standard,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.please_confirm_your_password.9d4287d7",
                            );
                          }

                          if (value != _passwordController.text) {
                            return AppSettingsScope.translate(
                              context,
                              "vendor.passwords_do_not_match.b6eb82cd",
                            );
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 26),

                      // ==================================
                      // CREATE ACCOUNT BUTTON
                      // ==================================
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _wine.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _wine,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _wine.withValues(
                              alpha: 0.65,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: AppShimmerIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.create_account.798ca2ce",
                                  ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ==================================
                      // BACK TO LOGIN
                      // ==================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.already_have_an_account.04a38dd0",
                              ),
                              style: TextStyle(fontSize: 13, color: _hintColor),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: _wine,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.sign_in.bfd402b2",
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
