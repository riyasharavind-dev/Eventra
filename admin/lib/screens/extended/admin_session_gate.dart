import '../../services/app_live_data.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/admin_auth_link.dart';
import '../../utils/auth_browser.dart';
import '../auth/login_screen.dart';
import '../main/admin_main_screen.dart';
import 'admin_mfa_screen.dart';
import 'admin_password_screen.dart';

@visibleForTesting
bool adminAccessChanged(
  Map<String, dynamic>? previous,
  Map<String, dynamic>? current,
) {
  if (current == null) return true;
  return previous?['id'] != current['id'] ||
      previous?['access_level'] != current['access_level'] ||
      previous?['mfa_required'] != current['mfa_required'] ||
      !mapEquals(
        previous?['permissions'] as Map?,
        current['permissions'] as Map?,
      );
}

class AdminSessionGate extends StatefulWidget {
  final Uri? callbackUri;
  const AdminSessionGate({super.key, this.callbackUri});
  @override
  State<AdminSessionGate> createState() => _AdminSessionGateState();
}

class _AdminSessionGateState extends State<AdminSessionGate>
    with LiveDataState<AdminSessionGate> {
  @override
  Set<String> get liveDatasets => {
    'own:access',
    'own:admins',
    'own:team_permissions',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    if (action != null || checkingLink) return;
    try {
      Map<String, dynamic>? prior = _observedContext;
      try {
        prior ??= await identity;
      } catch (_) {
        /* Retry an initial offline check. */
      }
      final raw = await db.rpc('admin_context');
      final next = raw == null ? null : Map<String, dynamic>.from(raw as Map);
      if (!mounted) return;
      _observedContext = next;
      // Returning from a file chooser triggers a refresh of every watched
      // dataset. Close protected routes only if the server reports a change.
      if (adminAccessChanged(prior, next)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() {
          identity = Future.value(next);
        });
      }
    } catch (error, stack) {
      if (error is! PostgrestException ||
          !const ['42501', 'PGRST301', '28000'].contains(error.code)) {
        rethrow;
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() {
        identity = Future<Map<String, dynamic>?>.error(error, stack)..ignore();
      });
    }
  }

  Map<String, dynamic>? _observedContext;
  final db = Supabase.instance.client;
  @override
  bool get liveAlwaysActive => true;
  StreamSubscription<AuthState>? subscription;
  Future<Map<String, dynamic>?>? identity;
  String? action, linkError;
  bool checkingLink = false;
  static const invalidLink =
      'This reset link is invalid or expired. Request a new email and use its latest link.';
  @override
  void initState() {
    super.initState();
    final link = AdminAuthLink.parse(widget.callbackUri ?? Uri.base);
    action = link.action;
    checkingLink =
        widget.callbackUri != null && link.hasCredentials && !link.hasError;
    if (link.hasError) {
      linkError = invalidLink;
      clearAdminAuthUrl();
    }
    subscription = db.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted || checkingLink) return;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          setState(() {
            action ??= 'recovery';
            refresh();
          });
        } else if (state.event == AuthChangeEvent.signedOut) {
          clearAdminAuthUrl();
          setState(() {
            action = null;
            identity = null;
          });
        } else if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.mfaChallengeVerified) {
          setState(refresh);
        }
      },
      onError: (Object e) {
        if (mounted && action != null) {
          setState(() => linkError = invalidLink);
        }
      },
    );
    if (checkingLink) {
      verifyLink(link);
    } else {
      if (action != null && db.auth.currentSession == null) {
        linkError ??= invalidLink;
      }
      refresh();
    }
  }

  Future<void> verifyLink(AdminAuthLink link) async {
    try {
      final result = await db.auth.getSessionFromUrl(link.uri);
      if (!mounted) return;
      final type = result.redirectType?.toString().toLowerCase() ?? '';
      action ??= type.contains('recovery')
          ? 'recovery'
          : type.contains('invite')
          ? 'setup'
          : null;
      setAdminAuthAction(action);
      setState(() {
        checkingLink = false;
        refresh();
      });
    } catch (_) {
      clearAdminAuthUrl();
      if (mounted) {
        setState(() {
          checkingLink = false;
          linkError = invalidLink;
        });
      }
    }
  }

  void refresh() {
    _observedContext = null;
    identity = db.auth.currentSession == null
        ? null
        : db
              .rpc('admin_context')
              .then(
                (value) => value == null
                    ? null
                    : Map<String, dynamic>.from(value as Map),
              );
  }

  void completed() {
    clearAdminAuthUrl();
    setState(() {
      action = null;
      refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (checkingLink) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening your secure reset link…'),
            ],
          ),
        ),
      );
    }
    // An invalid email link must never fall back to an existing unrelated session.
    if (linkError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset Password')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(linkError!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminPasswordScreen(forgot: true),
                      ),
                    ),
                    child: const Text('Request new reset link'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await db.auth.signOut();
                      if (mounted) {
                        setState(() {
                          linkError = null;
                          action = null;
                        });
                      }
                    },
                    child: const Text('Back to login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (db.auth.currentSession == null) return const LoginScreen();
    // Recovery shows the new-password form immediately. Any existing MFA challenge
    // is completed inside that form before Auth permits the password update.
    if (action == 'recovery') {
      return AdminPasswordScreen(onCompleted: completed);
    }
    if (action == 'setup') {
      final assurance = db.auth.mfa.getAuthenticatorAssuranceLevel();
      if (assurance.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
          assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
        return AdminMfaScreen(onVerified: () => setState(refresh));
      }
      return AdminPasswordScreen(invitation: true, onCompleted: completed);
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: identity,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No active admin access. Contact your owner if access was suspended or your invitation is pending.',
                  ),
                  TextButton(
                    onPressed: () => db.auth.signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          );
        }
        final level = db.auth.mfa.getAuthenticatorAssuranceLevel();
        if ((snapshot.data!['mfa_required'] == true ||
                level.nextLevel == AuthenticatorAssuranceLevels.aal2) &&
            level.currentLevel != AuthenticatorAssuranceLevels.aal2) {
          return AdminMfaScreen(onVerified: () => setState(refresh));
        }
        return const AdminMainScreen();
      },
    );
  }
}
