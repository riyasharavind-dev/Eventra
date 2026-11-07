import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/admin_authenticator_setup_card.dart';

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
        // Reuse an unverified enrollment only within this screen; remove stale
        // unverified TOTP factors left by an interrupted setup before enrolling.
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
    appBar: AppBar(
      title: const Text('Authenticator Verification'),
      actions: [
        TextButton(
          onPressed: () => auth.signOut(),
          child: const Text('Sign out'),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.security, size: 52),
              const SizedBox(height: 24),
              if (secret != null && qrSvg != null)
                AdminAuthenticatorSetupCard(qrSvg: qrSvg!, secret: secret!)
              else
                Text(
                  busy
                      ? 'Preparing authenticator…'
                      : 'Enter the six-digit code from your authenticator.',
                ),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Authenticator code',
                ),
                onChanged: (v) => setState(() => code = v.trim()),
                onSubmitted: (_) => verify(),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed:
                    busy || factor == null || !RegExp(r'^\d{6}$').hasMatch(code)
                    ? null
                    : verify,
                child: Text(busy ? 'Please wait…' : 'Verify'),
              ),
              if (factor == null && !busy)
                TextButton(onPressed: load, child: const Text('Retry')),
              const SizedBox(height: 20),
              const Text(
                'Owner and Admin accounts require an authenticator. Lost device? Contact another owner for the documented recovery process; email reset does not bypass MFA.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
