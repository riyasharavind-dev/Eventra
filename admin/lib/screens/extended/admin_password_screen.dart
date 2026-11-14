import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/admin_password_repository.dart';
import '../../utils/auth_browser.dart';
import 'admin_authenticator_recovery_screen.dart';

String? adminPasswordError(String? value) =>
    (value?.length ?? 0) < 12 ? 'Use at least 12 characters.' : null;

class AdminPasswordScreen extends StatefulWidget {
  final bool forgot, invitation;
  final VoidCallback? onCompleted;
  final AdminPasswordRepository? repository;
  const AdminPasswordScreen({
    super.key,
    this.forgot = false,
    this.invitation = false,
    this.onCompleted,
    this.repository,
  });
  @override
  State<AdminPasswordScreen> createState() => _AdminPasswordScreenState();
}

class _AdminPasswordScreenState extends State<AdminPasswordScreen> {
  final form = GlobalKey<FormState>();
  late final repo = widget.repository ?? AdminPasswordRepository();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();

  @override
  void dispose() {
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  String email = '', code = '';
  bool busy = false, sent = false, saved = false, hidden = true;
  String? error;

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.forgot) {
        await repo.requestReset(email);
        if (mounted) setState(() => sent = true);
      } else {
        await repo.savePassword(
          newPassword.text,
          code: code,
          invitation: widget.invitation,
        );
        if (mounted) {
          TextInput.finishAutofillContext();
          clearAdminAuthUrl();
          if (widget.invitation && widget.onCompleted != null) {
            widget.onCompleted!();
          } else {
            setState(() {
              saved = true;
              newPassword.clear();
              confirmPassword.clear();
              code = '';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is AuthException
              ? e.message
              : e.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> login() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.signOut();
      if (mounted) {
        widget.onCompleted?.call();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is AuthException
              ? e.message
              : e.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      title: Text(
        widget.forgot
            ? 'Forgot Password'
            : widget.invitation
            ? 'Set Your Password'
            : 'Reset Password',
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFF0EDF0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF80152C).withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: saved
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 32,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Password reset successfully',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your administrator password has been updated. You can now sign in.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF73737D),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFC62828),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: busy ? null : login,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF80152C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Back to login'),
                        ),
                      ),
                    ],
                  )
                : sent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5E8EC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            size: 30,
                            color: Color(0xFF80152C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Check your email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If this account exists in our administrator directory, you will receive an email shortly with a secure reset link.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF73737D),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF80152C),
                        ),
                        child: const Text('Back to login'),
                      ),
                    ],
                  )
                : AutofillGroup(
                    onDisposeAction: AutofillContextAction.cancel,
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.forgot
                                ? 'Enter your work email address to receive password recovery instructions.'
                                : 'Set a new secure password for your administrator account.',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF73737D),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (widget.forgot)
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Work email',
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF73737D),
                                  size: 20,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (v) => email = v,
                              validator: (v) =>
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(v?.trim() ?? '')
                                  ? null
                                  : 'Enter a valid email',
                            )
                          else ...[
                            TextFormField(
                              obscureText: hidden,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: 'New password',
                                helperText: 'At least 12 characters',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF73737D),
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => hidden = !hidden),
                                  icon: Icon(
                                    hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF73737D),
                                    size: 20,
                                  ),
                                ),
                              ),
                              controller: newPassword,
                              validator: adminPasswordError,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              obscureText: hidden,
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: Icon(
                                  Icons.lock_reset_outlined,
                                  color: Color(0xFF73737D),
                                  size: 20,
                                ),
                              ),
                              controller: confirmPassword,
                              validator: (v) => v == newPassword.text
                                  ? null
                                  : 'Passwords do not match',
                            ),
                            if (repo.needsMfa) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 6,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Authenticator code',
                                  helperText: 'Enter code from your registered authenticator application.',
                                  prefixIcon: Icon(
                                    Icons.security,
                                    color: Color(0xFF73737D),
                                    size: 20,
                                  ),
                                ),
                                onChanged: (v) => code = v,
                                validator: (v) =>
                                    RegExp(r'^\d{6}$').hasMatch(v ?? '')
                                    ? null
                                    : 'Enter the six-digit code',
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const AdminAuthenticatorRecoveryScreen(),
                                        ),
                                      ),
                                child: const Text('Add a new authenticator'),
                              ),
                            ],
                          ],
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFFCDD2),
                                  ),
                                ),
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: Color(0xFFC62828),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: busy ? null : submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF80152C),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                busy
                                    ? 'Please wait…'
                                    : widget.forgot
                                    ? 'Send reset link'
                                    : 'Save password',
                              ),
                            ),
                          ),
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
