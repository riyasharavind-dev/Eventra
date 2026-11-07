import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays only the current enrollment supplied by Supabase Auth.
/// Never fetches a QR image from an external service or persists the secret.
class AdminAuthenticatorSetupCard extends StatelessWidget {
  final String qrSvg;
  final String secret;
  const AdminAuthenticatorSetupCard({
    super.key,
    required this.qrSvg,
    required this.secret,
  });

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: secret));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setup key copied.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not copy. Select the key below to copy it manually.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Microsoft Authenticator → + → Other account → Scan QR code.'),
      const SizedBox(height: 20),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SvgPicture.string(
                  qrSvg,
                  key: const ValueKey('authenticator-setup-qr'),
                  fit: BoxFit.contain,
                  semanticsLabel: 'Scan this QR code with your authenticator to connect Eventor Admin',
                  errorBuilder: (_, error, stackTrace) => const Center(
                    child: Text(
                      'QR preview unavailable. Use the setup key below.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Can’t scan? Enter this setup key manually.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          secret,
          key: const ValueKey('authenticator-manual-key'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
      Center(
        child: TextButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_outlined, size: 18),
          label: const Text('Copy setup key'),
        ),
      ),
      const Text(
        'For manual setup: account name “Eventor Admin”, type “Time-based”. Then enter the six-digit code below.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
    ],
  );
}
