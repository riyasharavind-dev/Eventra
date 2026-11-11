import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../widgets/common/app_shimmer.dart';
import '../../utils/auth_error_message.dart';

import 'package:flutter/material.dart';

import '../../repositories/auth_repository.dart';
import 'password_recovery_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthRepository _authRepository = AuthRepository();

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Color _wine = Color(0xFF80152C);
  static const Color _background = Color(0xFFF8F8FA);
  static const Color _textColor = Color(0xFF17171B);
  static const Color _hintColor = Color(0xFF85838E);
  static const Color _borderColor = Color(0xFFE5E5EB);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      hintStyle: const TextStyle(
        color: _hintColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, size: 21, color: AppIconColors.standard),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
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
  // SIGN IN
  // ==========================================

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.user != null && response.session != null) {
        // Supabase auth state change handles navigation.
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettingsScope.translate(
              context,
              "vendor.login_failed_please_try_again.c95b4875",
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
  // OPEN SIGNUP
  // ==========================================

  Future<void> _openPasswordRecovery() async {
    FocusScope.of(context).unfocus();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PasswordRecoveryScreen(initialEmail: _emailController.text.trim()),
      ),
    );
    if (!mounted || changed != true) return;
    _passwordController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppSettingsScope.of(context)
              .text('Password updated. Sign in with your new password.'),
        ),
      ),
    );
  }

  void _openSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // ==================================
                    // HEADING
                    // ==================================
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.welcome_back.66212495",
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
                        "vendor.sign_in_to_continue_to_your_account.52fa0f48",
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: _hintColor,
                      ),
                    ),

                    const SizedBox(height: 34),

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

                    const SizedBox(height: 9),

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

                        final email = value.trim();

                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return AppSettingsScope.translate(
                            context,
                            "vendor.please_enter_a_valid_email.845babfe",
                          );
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

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

                    const SizedBox(height: 9),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: _inputDecoration(
                        hint: AppSettingsScope.translate(
                          context,
                          "vendor.enter_your_password.c06bf967",
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
                            "vendor.please_enter_your_password.f7eab111",
                          );
                        }

                        return null;
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _openPasswordRecovery,
                        style: TextButton.styleFrom(foregroundColor: _wine),
                        child: Text(
                          AppSettingsScope.of(context).text('Forgot password?'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ==================================
                    // SIGN IN BUTTON
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
                        onPressed: _isLoading ? null : _signIn,
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
                                width: 22,
                                height: 22,
                                child: AppShimmerIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "vendor.sign_in.bfd402b2",
                                    ),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 9),
                                  Icon(Icons.arrow_forward_rounded, size: 19),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ==================================
                    // SIGNUP LINK
                    // ==================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            AppSettingsScope.translate(
                              context,
                              "vendor.don_t_have_an_account.cb6f6b83",
                            ),
                            style: TextStyle(fontSize: 13, color: _hintColor),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _openSignup,
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
                              "vendor.create_account.798ca2ce",
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
