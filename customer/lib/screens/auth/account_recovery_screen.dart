import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/password_recovery_repository.dart';
import '../../utils/auth_error_message.dart';
import '../../widgets/auth/customer_auth_layout.dart';

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({
    super.key,
    this.repository,
    this.emailDeliveryReady = emailCodesReady,
    this.resendCooldown = const Duration(seconds: 60),
  });
  static const emailCodesReady = bool.fromEnvironment(
    'CUSTOMER_EMAIL_CODE_READY',
  );
  final PasswordRecoveryRepository? repository;
  final bool emailDeliveryReady;
  final Duration resendCooldown;
  @override
  State<AccountRecoveryScreen> createState() => _RecoveryState();
}

class _RecoveryState extends State<AccountRecoveryScreen> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  late final repo = widget.repository ?? PasswordRecoveryRepository();
  bool sent = false, verified = false, busy = false;
  String? requestedEmail, error;
  Timer? timer;
  DateTime? retryAt;
  int seconds = 0;
  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void cooldown() {
    timer?.cancel();
    retryAt = DateTime.now().add(widget.resendCooldown);
    seconds = widget.resendCooldown.inSeconds;
    if (seconds <= 0) return;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = retryAt!.difference(DateTime.now()).inMilliseconds;
      setState(() => seconds = remaining <= 0 ? 0 : (remaining / 1000).ceil());
      if (seconds == 0) timer?.cancel();
    });
  }

  Future<void> send() async {
    if (busy || !widget.emailDeliveryReady || seconds > 0) return;
    final address = (requestedEmail ?? email.text).trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      setState(
        () => error = authText(
          context,
          'Enter a valid email address.',
          'சரியான மின்னஞ்சல் முகவரியை உள்ளிடவும்.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Resending always requests another password-recovery email, never signup verification.
      await repo.request(address);
      if (!mounted) return;
      setState(() {
        requestedEmail = address;
        sent = true;
        code.clear();
        cooldown();
      });
    } catch (e) {
      if (mounted) setState(() => error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (busy || !sent || requestedEmail == null || code.text.trim().isEmpty) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.verify(requestedEmail!, code.text.trim());
      if (mounted) {
        setState(() {
          verified = true;
          timer?.cancel();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              e is AuthException &&
                  (e.code == 'otp_expired' ||
                      e.message.toLowerCase().contains('expired'))
              ? authText(
                  context,
                  'This code expired or is invalid. Request a new email below.',
                  'இந்த குறியீடு காலாவதியானது அல்லது செல்லாது. கீழே புதிய மின்னஞ்சலைக் கோரவும்.',
                )
              : authErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || !verified) return;
    if (password.text.length < 8 || password.text != confirm.text) {
      setState(
        () => error = authText(
          context,
          'Use at least 8 characters and enter the same password twice.',
          'குறைந்தது 8 எழுத்துகளுடன் ஒரே கடவுச்சொல்லை இருமுறை உள்ளிடவும்.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.save(password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authText(
              context,
              'Password updated. Sign in with your new password.',
              'கடவுச்சொல் புதுப்பிக்கப்பட்டது. புதிய கடவுச்சொல்லுடன் உள்நுழையவும்.',
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text(
          authText(context, 'Reset Password', 'கடவுச்சொல்லை மீட்டமை'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!widget.emailDeliveryReady)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    authText(
                      context,
                      'Email code delivery is being configured. Please contact Eventor support if you cannot sign in.',
                      'மின்னஞ்சல் குறியீடு அனுப்பும் வசதி அமைக்கப்படுகிறது. உள்நுழைய முடியாவிட்டால் Eventor உதவிக் குழுவைத் தொடர்புகொள்ளவும்.',
                    ),
                    style: const TextStyle(color: Color(0xFF73737D), height: 1.5),
                  ),
                ),
              if (!verified) ...[
                TextField(
                  key: const ValueKey('recovery-email'),
                  controller: email,
                  enabled: !busy && !sent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: authText(
                      context,
                      'Email Address',
                      'மின்னஞ்சல் முகவரி',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!sent)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: authWine,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: busy || !widget.emailDeliveryReady || seconds > 0
                        ? null
                        : send,
                    child: Text(
                      authText(
                        context,
                        'Send Reset Email',
                        'மீட்டமைப்பு மின்னஞ்சலை அனுப்பு',
                      ),
                    ),
                  ),
                if (sent) ...[
                  Text(
                    authText(
                      context,
                      'If this account is eligible, a reset email has been sent. Check your inbox and spam folder.',
                      'இந்த கணக்கு தகுதியானதாக இருந்தால் மீட்டமைப்பு மின்னஞ்சல் அனுப்பப்பட்டுள்ளது. இன்பாக்ஸ் மற்றும் தேவையற்ற அஞ்சல் பகுதியைப் பார்க்கவும்.',
                    ),
                    style: const TextStyle(color: Color(0xFF73737D), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('recovery-code'),
                    controller: code,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: authText(
                        context,
                        'Email code',
                        'மின்னஞ்சல் குறியீடு',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: authWine,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: busy ? null : verify,
                    child: Text(
                      authText(context, 'Verify Code', 'குறியீட்டைச் சரிபார்'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    authText(
                      context,
                      'Didn’t receive the email, or has your code expired?',
                      'மின்னஞ்சல் வரவில்லையா அல்லது குறியீடு காலாவதியாகிவிட்டதா?',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF73737D)),
                  ),
                  TextButton(
                    key: const ValueKey('recovery-resend'),
                    onPressed: busy || seconds > 0 ? null : send,
                    child: Text(
                      seconds > 0
                          ? '${authText(context, "Resend Email", "மின்னஞ்சலை மீண்டும் அனுப்பு")} (${seconds}s)'
                          : authText(
                              context,
                              'Resend Email',
                              'மின்னஞ்சலை மீண்டும் அனுப்பு',
                            ),
                      style: const TextStyle(color: authWine, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ] else ...[
                TextField(
                  key: const ValueKey('recovery-password'),
                  controller: password,
                  enabled: !busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: authText(
                      context,
                      'New Password',
                      'புதிய கடவுச்சொல்',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirm,
                  enabled: !busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: authText(
                      context,
                      'Confirm Password',
                      'கடவுச்சொல்லை உறுதிப்படுத்து',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: authWine,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: busy ? null : save,
                  child: Text(
                    authText(
                      context,
                      'Save New Password',
                      'புதிய கடவுச்சொல்லைச் சேமி',
                    ),
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(error!, style: const TextStyle(color: authWine)),
                ),
              if (busy)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Text(
                      authText(context, 'Please wait…', 'சற்று காத்திருக்கவும்…'),
                      style: const TextStyle(color: Color(0xFF73737D)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
