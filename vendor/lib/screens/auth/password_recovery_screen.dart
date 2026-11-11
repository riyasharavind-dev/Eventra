import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../repositories/auth_repository.dart';
import '../../services/app_settings_controller.dart';
import '../../utils/auth_error_message.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, required this.initialEmail});
  final String initialEmail;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  static const _emailReady = bool.fromEnvironment('VENDOR_EMAIL_CODE_READY');
  static const _wine = Color(0xFF80152C);
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // Keep recovery sessions separate from the session that opens the dashboard.
  SupabaseClient? _client;
  SupabaseClient get _recovery => _client ??= SupabaseClient(
    SupabaseConfig.url,
    SupabaseConfig.anonKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _sent = false, _verified = false, _busy = false;
  String? _error;
  String get _address => _email.text.trim();
  String _text(String source) => AppSettingsScope.of(context).text(source);

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    final client = _client;
    if (client != null) unawaited(client.dispose());
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AuthException && error.code == 'otp_expired'
              ? 'This code is invalid or expired. Request a new email.'
              : authErrorMessage(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (!_emailReady || _busy || _resendSeconds > 0) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_address)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    await _perform(() async {
      try {
        await _recovery.auth.resetPasswordForEmail(_address);
      } on AuthException catch (error) {
        if (error.code != 'user_not_found') rethrow;
      }
      if (!mounted) return;
      setState(() {
        _sent = true;
        _code.clear();
        _resendSeconds = 60;
      });
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _resendSeconds--);
        if (_resendSeconds == 0) timer.cancel();
      });
    });
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    await _perform(() async {
      final response = await _recovery.auth.verifyOTP(
        email: _address,
        token: _code.text.trim(),
        type: OtpType.recovery,
      );
      if (response.session == null) {
        throw const AccountAccessException('Request a new recovery code.');
      }
      await AuthRepository(client: _recovery).validateAccountRole();
      if (mounted) setState(() => _verified = true);
    });
  }

  Future<void> _save() async {
    if (!_verified || !_form.currentState!.validate()) return;
    await _perform(() async {
      await _recovery.auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: _text(label),
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(title: Text(_text('Reset password'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_emailReady)
                      Text(
                        _text(
                          'Password reset emails are not available yet. Please contact Eventor support.',
                        ),
                      )
                    else if (_verified) ...[
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: _input('New password', Icons.lock_outline),
                        validator: (value) => (value?.length ?? 0) < 8
                            ? _text('Use at least 8 characters.')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        enabled: !_busy,
                        obscureText: true,
                        decoration: _input(
                          'Confirm password',
                          Icons.lock_outline,
                        ),
                        validator: (value) => value != _password.text
                            ? _text('Passwords do not match.')
                            : null,
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _email,
                        enabled: !_sent && !_busy,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _input(
                          'Vendor email address',
                          Icons.email_outlined,
                        ),
                      ),
                      if (_sent) ...[
                        const SizedBox(height: 14),
                        Text(
                          _text(
                            'If the email is registered, check your inbox or spam folder for a reset code.',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _code,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _input(
                            'Email code',
                            Icons.password_outlined,
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? _text('Enter the code from your email.')
                              : null,
                        ),
                      ],
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _text(_error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (_emailReady) ...[
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _wine,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy
                            ? null
                            : (_verified
                                  ? _save
                                  : _sent
                                  ? _verify
                                  : _send),
                        child: Text(
                          _text(
                            _busy
                                ? 'Please wait…'
                                : _verified
                                ? 'Save new password'
                                : _sent
                                ? 'Verify code'
                                : 'Send reset email',
                          ),
                        ),
                      ),
                      if (_sent && !_verified)
                        TextButton(
                          onPressed: _busy || _resendSeconds > 0 ? null : _send,
                          child: Text(
                            _resendSeconds > 0
                                ? '${_text('Resend email')} (${_resendSeconds}s)'
                                : _text('Resend email'),
                          ),
                        ),
                    ],
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
