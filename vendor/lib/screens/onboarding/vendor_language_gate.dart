import 'package:flutter/material.dart';

import '../../repositories/app_settings_repository.dart';
import '../extended/language_screen.dart';

/// Ask once per installation before onboarding/sign-in, then use the cached choice.
class VendorLanguageGate extends StatefulWidget {
  const VendorLanguageGate({super.key, required this.child, this.repository});
  final Widget child;
  final AppSettingsRepository? repository;
  @override
  State<VendorLanguageGate> createState() => _VendorLanguageGateState();
}

class _VendorLanguageGateState extends State<VendorLanguageGate> {
  bool? selected;
  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    var value = false;
    try {
      value = await (widget.repository ?? AppSettingsRepository())
          .hasSelectedLanguage();
    } catch (_) {
      /* Keep the picker available if local storage cannot be read. */
    }
    if (mounted) setState(() => selected = value);
  }

  @override
  Widget build(BuildContext context) {
    if (selected == null) return const Scaffold(body: SizedBox.expand());
    if (selected!) return widget.child;
    return LanguageScreen(onSelected: () => setState(() => selected = true));
  }
}
