import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/admin_password_repository.dart';
import '../../utils/auth_browser.dart';

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
        setState(
          () => error = e is AuthException
              ? e.message
              : e.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.signOut();
      if (mounted) widget.onCompleted?.call();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Password saved. Could not sign out yet; try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
          constraints: const BoxConstraints(maxWidth: 440),
          child: saved
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Password reset successfully',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in with your new password.',
                      textAlign: TextAlign.center,
                    ),
                    if (error != null) Text(error!),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : login,
                      child: const Text('Back to login'),
                    ),
                  ],
                )
              : sent
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 56),
                    const SizedBox(height: 20),
                    Text(
                      'Check your email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'If this account is eligible, you’ll receive an email. Click “Reset password” in that email, enter your new password, then save it.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Back to login'),
                    ),
                  ],
                )
              : Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.forgot
                            ? 'Enter your work email. We’ll send you a reset link.'
                            : 'Enter your new password below.',
                      ),
                      const SizedBox(height: 24),
                      if (widget.forgot)
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Work email',
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
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => hidden = !hidden),
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
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
                            autofillHints: const [AutofillHints.oneTimeCode],
                            decoration: const InputDecoration(
                              labelText: 'Authenticator code',
                              helperText: 'Use the six-digit code from your connected authenticator.',
                            ),
                            onChanged: (v) => code = v,
                            validator: (v) =>
                                RegExp(r'^\d{6}$').hasMatch(v ?? '')
                                ? null
                                : 'Enter the six-digit code',
                          ),
                        ],
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: busy ? null : submit,
                        child: Text(
                          busy
                              ? 'Please wait…'
                              : widget.forgot
                              ? 'Send reset link'
                              : 'Save password',
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
