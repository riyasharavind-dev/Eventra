import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../utils/auth_error_message.dart';

/// Keeps protected screens hidden until the database confirms the account type.
class AccountRoleGate extends StatefulWidget {
  const AccountRoleGate({super.key, required this.child});
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
    _check = AuthRepository().validateAccountRole();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _check,
    builder: (context, snapshot) {
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
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await AuthRepository().signOut();
                    },
                    child: const Text('Back to sign in'),
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
