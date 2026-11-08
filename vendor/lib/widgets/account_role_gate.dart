import 'package:eventor_vendor/core/theme/app_icon_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_live_data.dart';
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
        return const Scaffold(
          body: Center(
            child: AppContentSkeleton(layout: SkeletonLayout.profile),
          ),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F8FA),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E8EC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 36,
                      color: AppIconColors.standard,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    authErrorMessage(snapshot.error!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF17171B),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF80152C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _check = AuthRepository().validateAccountRole();
                      });
                    },
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF73737D),
                    ),
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
