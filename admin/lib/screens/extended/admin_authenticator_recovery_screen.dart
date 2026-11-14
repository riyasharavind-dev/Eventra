import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminAuthenticatorRecoveryScreen extends StatelessWidget {
  const AdminAuthenticatorRecoveryScreen({super.key, this.accountEmail});

  final String? accountEmail;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add a new authenticator')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Still have your authenticator?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your authenticator app’s transfer or backup restore '
                'feature on the new device. Return here and enter the '
                'six-digit Eventor code from that device.',
              ),
              const SizedBox(height: 24),
              Text(
                'Lost access to your authenticator?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Contact your Eventor owner. A trusted Supabase project '
                'operator will verify your identity and remove the lost '
                'authenticator. Share your sign-in email only.',
              ),
              if (accountEmail case final email?) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: SelectableText(email),
                  trailing: IconButton(
                    tooltip: 'Copy sign-in email',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: email));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sign-in email copied')),
                        );
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'After the operator confirms the reset, sign out and sign '
                'back in. Scan the new QR code and enter the six-digit code '
                'to finish setup.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
