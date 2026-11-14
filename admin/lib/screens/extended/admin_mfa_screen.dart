import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/admin_authenticator_setup_card.dart';
import 'admin_authenticator_recovery_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminMfaScreen extends StatefulWidget {
  final VoidCallback onVerified;
  const AdminMfaScreen({super.key, required this.onVerified});
  @override
  State<AdminMfaScreen> createState() => _AdminMfaScreenState();
}

class _AdminMfaScreenState extends State<AdminMfaScreen> {
  final auth = Supabase.instance.client.auth;
  String? factor, secret, qrSvg, error;
  String code = '';
  bool busy = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
      factor = null;
      secret = null;
      qrSvg = null;
    });
    try {
      final factors = await auth.mfa.listFactors();
      if (factors.totp.isNotEmpty) {
        factor = factors.totp.first.id;
      } else {
        for (final old in factors.all.where(
          (f) =>
              f.factorType == FactorType.totp &&
              f.status == FactorStatus.unverified,
        )) {
          await auth.mfa.unenroll(old.id);
        }
        final enrollment = await auth.mfa.enroll(
          factorType: FactorType.totp,
          friendlyName: 'Eventor Admin',
        );
        factor = enrollment.id;
        secret = enrollment.totp!.secret;
        qrSvg = enrollment.totp!.qrCode;
      }
    } catch (e) {
      error = e is AuthException
          ? e.message
          : 'Could not prepare authenticator. Retry.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> verify() async {
    if (busy || factor == null || !RegExp(r'^\d{6}$').hasMatch(code)) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await auth.mfa.challengeAndVerify(factorId: factor!, code: code);
      if (mounted) widget.onVerified();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AuthException
              ? e.message
              : 'Verification failed. Try the latest code.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      title: const Text('Authenticator Verification'),
      actions: [
        TextButton.icon(
          onPressed: () => auth.signOut(),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Sign out'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF80152C)),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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
            child: Column(
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
                      Icons.security_rounded,
                      size: 32,
                      color: Color(0xFF80152C),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Two-Factor Authentication',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17171B),
                  ),
                ),
                const SizedBox(height: 8),
                if (secret != null && qrSvg != null)
                  AdminAuthenticatorSetupCard(qrSvg: qrSvg!, secret: secret!)
                else
                  Text(
                    busy ? 'Preparing authenticator credentials…' : 'Enter the six-digit TOTP security code from your authenticator application.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF73737D),
                      height: 1.45,
                    ),
                  ),
                const SizedBox(height: 24),
                TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit authenticator code',
                    prefixIcon: Icon(
                      Icons.pin_outlined,
                      color: Color(0xFF73737D),
                      size: 20,
                    ),
                  ),
                  onChanged: (v) => setState(() => code = v.trim()),
                  onSubmitted: (_) => verify(),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
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
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed:
                        busy ||
                            factor == null ||
                            !RegExp(r'^\d{6}$').hasMatch(code)
                        ? null
                        : verify,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF80152C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(busy ? 'Verifying…' : 'Verify & Continue'),
                  ),
                ),
                if (factor == null && !busy) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry setup'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF80152C),
                    ),
                  ),
                ],
                if (!busy && secret == null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminAuthenticatorRecoveryScreen(
                          accountEmail: auth.currentUser?.email,
                        ),
                      ),
                    ),
                    child: const Text('Add a new authenticator'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
