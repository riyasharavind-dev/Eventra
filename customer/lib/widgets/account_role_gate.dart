import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../utils/auth_error_message.dart';

/// Keeps protected screens hidden until the database confirms the account type.
class AccountRoleGate extends StatefulWidget {
  const AccountRoleGate({
    super.key,
    required this.child,
    this.allowGuest = false,
    this.accountId,
  });
  final bool allowGuest;
  final String? accountId;
  final Widget child;
  @override
  State<AccountRoleGate> createState() => _AccountRoleGateState();
}

class _AccountRoleGateState extends State<AccountRoleGate>
    with LiveDataState<AccountRoleGate> {
  @override
  Set<String> get liveDatasets => {'own:access', 'own:users', 'own:admins'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    if (widget.allowGuest &&
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }
    // Successful revalidation must not unmount the app or erase an open form.
    try {
      await AuthRepository().validateAccountRole();
    } catch (error, stack) {
      final denied =
          error is AccountAccessException ||
          (error is PostgrestException &&
              const ['42501', 'PGRST301', '28000'].contains(error.code));
      if (!denied) {
        rethrow; // Offline revalidation must preserve the open app/form.
      }
      if (!mounted) return;
      setState(() {
        _check = Future<void>.error(error, stack)..ignore();
      });
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  bool get liveAlwaysActive => true;

  late Future<void> _check;
  @override
  void initState() {
    super.initState();
    _check = validate();
  }

  Future<void> validate() =>
      widget.allowGuest && Supabase.instance.client.auth.currentSession == null
      ? Future.value()
      : AuthRepository().validateAccountRole();
  @override
  void didUpdateWidget(covariant AccountRoleGate old) {
    super.didUpdateWidget(old);
    if (old.accountId != widget.accountId) {
      _check = validate();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _check,
    builder: (context, snapshot) {
      if (widget.allowGuest) {
        final ready =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(offstage: !ready, child: widget.child),
            if (!ready)
              Scaffold(
                body: Center(
                  child: snapshot.hasError
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(authErrorMessage(snapshot.error!)),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _check = validate()),
                              child: const Text('Retry'),
                            ),
                            TextButton(
                              onPressed: () => AuthRepository().signOut(),
                              child: const Text('Continue browsing'),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
          ],
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    authErrorMessage(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _check = AuthRepository().validateAccountRole();
                      });
                    },
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.try_again.d8b8392e",
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await AuthRepository().signOut();
                    },
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.back_to_sign_in.71fe31cc",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return widget.child;
    },
  );
}
