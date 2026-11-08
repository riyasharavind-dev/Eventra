import '../utils/auth_error_message.dart';
import '../models/account_security_action.dart';

import 'package:flutter/material.dart';

import '../models/account_security_model.dart';
import '../repositories/account_security_repository.dart';

Future<void> showAccountSecurityAction(
  BuildContext context,
  AccountSecurityAction action, {
  AccountSecurityRepository? repository,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        AccountSecurityDialog(action: action, repository: repository),
  );
}

class AccountSecurityDialog extends StatefulWidget {
  const AccountSecurityDialog({
    super.key,
    required this.action,
    this.repository,
  });
  final AccountSecurityAction action;
  final AccountSecurityRepository? repository;
  @override
  State<AccountSecurityDialog> createState() => _AccountSecurityDialogState();
}

class _AccountSecurityDialogState extends State<AccountSecurityDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _reason = TextEditingController();
  final _code = TextEditingController();
  late final AccountSecurityRepository _repository;
  AccountSecurityModel? _account;
  bool _loading = true;
  bool _busy = false;
  bool _hidden = true;
  bool _confirmed = false;
  bool _showCode = false;
  bool _emailSent = false;
  String? _error;
  String? _notice;

  String get _title => switch (widget.action) {
    AccountSecurityAction.password => 'Change Password',
    AccountSecurityAction.email => 'Change Email',
    AccountSecurityAction.phone => 'Phone Number',
    AccountSecurityAction.deleteAccount => 'Delete Account',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AccountSecurityRepository();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _password,
      _newPassword,
      _confirmPassword,
      _email,
      _phone,
      _reason,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _message(Object error) => authErrorMessage(error);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await _repository.load();
      if (!mounted) return;
      setState(() {
        if (_account == null) _phone.text = account.phone ?? '';
        _account = account;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(error);
        });
      }
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.action == AccountSecurityAction.deleteAccount && !_confirmed) {
      setState(
        () => _error = 'Confirm that you want to request account deletion.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      switch (widget.action) {
        case AccountSecurityAction.password:
          await _repository.changePassword(
            currentPassword: _password.text,
            newPassword: _newPassword.text,
            nonce: _showCode ? _code.text : null,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Password updated.')));
          Navigator.of(context).pop();
          break;
        case AccountSecurityAction.email:
          await _repository.changeEmail(
            currentPassword: _password.text,
            email: _email.text,
          );
          _password.clear();
          if (!mounted) return;
          await _load();
          if (!mounted) return;
          setState(() {
            _emailSent = true;
            _notice = _account!.pendingEmail?.isNotEmpty == true
                ? 'Confirmation sent. Check your new inbox and, if requested, your current inbox. Confirm the email links, then refresh below.'
                : 'Email updated. Your Auth server did not require further confirmation.';
          });
          break;
        case AccountSecurityAction.phone:
          await _repository.updatePhone(_phone.text);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact phone updated.')),
          );
          Navigator.of(context).pop();
          break;
        case AccountSecurityAction.deleteAccount:
          await _repository.requestDeletion(
            password: _password.text,
            reason: _reason.text,
          );
          _password.clear();
          if (!mounted) return;
          await _load();
          if (mounted) {
            setState(
              () => _notice = 'Deletion request submitted. Your account has not been deleted. An administrator will review the request.',
            );
          }
          break;
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _securityCode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.sendPasswordCode();
      if (mounted) {
        setState(() {
          _showCode = true;
          _notice = 'Check your email for the security code.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel deletion request?'),
        content: const Text('Your account will remain active.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.cancelDeletion();
      if (!mounted) return;
      await _load();
      if (mounted) {
        setState(() {
          _confirmed = false;
          _notice = 'Deletion request cancelled.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _secret(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_busy,
        obscureText: _hidden,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Show password' : 'Hide password',
            onPressed: _busy ? null : () => setState(() => _hidden = !_hidden),
            icon: Icon(
              _hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        validator:
            validator ??
            (value) => value == null || value.isEmpty
                ? 'Enter your current password.'
                : null,
      ),
    );
  }

  List<Widget> _fields() {
    final account = _account!;
    switch (widget.action) {
      case AccountSecurityAction.password:
        return [
          const Text('Confirm your current password and choose a new one.'),
          _secret(_password, 'Current password'),
          _secret(
            _newPassword,
            'New password',
            validator: (value) {
              if ((value?.length ?? 0) < 8) return 'Use at least 8 characters.';
              if (value == _password.text) {
                return 'Choose a different password.';
              }
              return null;
            },
          ),
          _secret(
            _confirmPassword,
            'Confirm new password',
            validator: (value) =>
                value == _newPassword.text ? null : 'Passwords do not match.',
          ),
          TextButton(
            onPressed: _busy ? null : _securityCode,
            child: const Text('Security code required? Send code'),
          ),
          if (_showCode)
            TextFormField(
              controller: _code,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Email security code',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.trim().isEmpty != false
                  ? 'Enter the security code.'
                  : null,
            ),
        ];
      case AccountSecurityAction.email:
        return [
          Text('Current email: ${account.email}'),
          if (account.pendingEmail?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text('Awaiting confirmation: ${account.pendingEmail}'),
          ],
          if (!_emailSent) ...[
            const SizedBox(height: 18),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'New email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  return 'Enter a valid email address.';
                }
                if (email.toLowerCase() == account.email.toLowerCase()) {
                  return 'Enter a different email.';
                }
                return null;
              },
            ),
            _secret(_password, 'Current password'),
          ],
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('I have confirmed - refresh status'),
          ),
        ];
      case AccountSecurityAction.phone:
        return [
          const Text(
            'Contact number only. This does not change your sign-in method or verify the number by SMS.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _phone,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            maxLength: 16,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+919876543210',
              helperText: 'Include country code. Leave empty to remove.',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value?.trim().isNotEmpty == true &&
                    !RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(value!.trim())
                ? 'Use country code and digits, e.g. +919876543210.'
                : null,
          ),
        ];
      case AccountSecurityAction.deleteAccount:
        final request = account.deletionRequest;
        return [
          const Text(
            'This submits an account deletion request for administrator review. Your account and data are not deleted immediately.',
            style: TextStyle(height: 1.6),
          ),
          if (request != null) ...[
            const SizedBox(height: 16),
            Text(
              'Request status: ${request.label}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (request.publicNote?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(request.publicNote!),
              ),
          ],
          if (request?.active != true) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            _secret(_password, 'Current password'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmed,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
              title: const Text(
                'I want to request deletion of my Eventor account.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
          if (request?.status == 'pending')
            TextButton(
              onPressed: _busy ? null : _cancelRequest,
              child: const Text('Cancel deletion request'),
            ),
          if (request?.status == 'in_review')
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Your request is being reviewed. Contact support if you need help.',
              ),
            ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDeletion =
        widget.action == AccountSecurityAction.deleteAccount &&
        _account?.deletionRequest?.active == true;
    final canSave =
        !_loading &&
        _account != null &&
        !_busy &&
        !activeDeletion &&
        !(widget.action == AccountSecurityAction.email && _emailSent);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(_title),
        content: SizedBox(
          width: 420,
          child: _loading
              ? const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_account != null) ..._fields(),
                        if (_notice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _notice!,
                              style: const TextStyle(height: 1.5),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF9F0101),
                                height: 1.5,
                              ),
                            ),
                          ),
                        if (_account == null)
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!activeDeletion &&
              !(widget.action == AccountSecurityAction.email && _emailSent))
            FilledButton(
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9F0101),
              ),
              child: Text(
                _busy
                    ? 'Please wait...'
                    : widget.action == AccountSecurityAction.deleteAccount
                    ? 'Request deletion'
                    : widget.action == AccountSecurityAction.email
                    ? 'Update email'
                    : 'Save',
              ),
            ),
        ],
      ),
    );
  }
}
