import 'common/app_shimmer.dart';

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

class _AccountRoleGateState extends State<AccountRoleGate> {
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
        return const Scaffold(
          body: Center(
            child: AppContentSkeleton(layout: SkeletonLayout.profile),
          ),
        );
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
