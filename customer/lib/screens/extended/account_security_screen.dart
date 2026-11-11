import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../utils/auth_error_message.dart';
import '../../models/account_security_action.dart';

import 'package:flutter/material.dart';

import '../../models/account_security_model.dart';
import '../../repositories/account_security_repository.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({
    super.key,
    required this.action,
    this.repository,
  });
  final AccountSecurityAction action;
  final AccountSecurityRepository? repository;
  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.password_updated.df01ff0d",
                ),
              ),
            ),
          );
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
            SnackBar(
              content: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.contact_phone_updated.e0b7fc70",
                ),
              ),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          AppSettingsScope.translate(
            context,
            "customer.cancel_deletion_request.efb7562b",
          ),
        ),
        content: Text(
          AppSettingsScope.translate(
            context,
            "customer.your_account_will_remain_active.6ce9e6bf",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.keep_request.3259de86",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.cancel_request.56196683",
              ),
            ),
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
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Show password' : 'Hide password',
            onPressed: _busy ? null : () => setState(() => _hidden = !_hidden),
            icon: Icon(
              _hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF73737D),
            ),
          ),
        ),
        validator:
            validator ??
            (value) => value == null || value.isEmpty
                ? AppSettingsScope.translate(
                    context,
                    "customer.enter_your_current_password.cf4d205e",
                  )
                : null,
      ),
    );
  }

  List<Widget> _fields() {
    final account = _account!;
    switch (widget.action) {
      case AccountSecurityAction.password:
        return [
          Text(
            AppSettingsScope.translate(
              context,
              "customer.confirm_your_current_password_and_choose_a_ne.e1ce0c51",
            ),
          ),
          _secret(_password, 'Current password'),
          _secret(
            _newPassword,
            'New password',
            validator: (value) {
              if ((value?.length ?? 0) < 8) {
                return AppSettingsScope.translate(
                  context,
                  "customer.use_at_least_8_characters.9b15ce9e",
                );
              }
              if (value == _password.text) {
                return AppSettingsScope.translate(
                  context,
                  "customer.choose_a_different_password.353fb0a7",
                );
              }
              return null;
            },
          ),
          _secret(
            _confirmPassword,
            'Confirm new password',
            validator: (value) => value == _newPassword.text
                ? null
                : AppSettingsScope.translate(
                    context,
                    "customer.passwords_do_not_match.6c6e178a",
                  ),
          ),
          TextButton(
            onPressed: _busy ? null : _securityCode,
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.security_code_required_send_code.ec7abe96",
              ),
            ),
          ),
          if (_showCode)
            TextFormField(
              controller: _code,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.email_security_code.0dade3e8",
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.trim().isEmpty != false
                  ? AppSettingsScope.translate(
                      context,
                      "customer.enter_the_security_code.023e26fa",
                    )
                  : null,
            ),
        ];
      case AccountSecurityAction.email:
        return [
          Text(
            AppSettingsScope.translate(
              context,
              "customer.current_email_value0.d6910595",
              args: {"value0": account.email},
            ),
          ),
          if (account.pendingEmail?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              AppSettingsScope.translate(
                context,
                "customer.awaiting_confirmation_value0.066a8de5",
                args: {"value0": account.pendingEmail},
              ),
            ),
          ],
          if (!_emailSent) ...[
            const SizedBox(height: 18),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.new_email.0d25c8b1",
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  return AppSettingsScope.translate(
                    context,
                    "customer.enter_a_valid_email_address.8a966af8",
                  );
                }
                if (email.toLowerCase() == account.email.toLowerCase()) {
                  return AppSettingsScope.translate(
                    context,
                    "customer.enter_a_different_email.53a02cfd",
                  );
                }
                return null;
              },
            ),
            _secret(_password, 'Current password'),
          ],
          TextButton(
            onPressed: _busy ? null : _load,
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.i_have_confirmed_refresh_status.cd42f6b2",
              ),
            ),
          ),
        ];
      case AccountSecurityAction.phone:
        return [
          Text(
            AppSettingsScope.translate(
              context,
              "customer.contact_number_only_this_does_not_change_your.72abd67d",
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _phone,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            maxLength: 16,
            decoration: InputDecoration(
              labelText: AppSettingsScope.translate(
                context,
                "customer.phone_number.306f1bb2",
              ),
              hintText: '+919876543210',
              helperText: AppSettingsScope.translate(
                context,
                "customer.include_country_code_leave_empty_to_remove.5baac4b4",
              ),
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value?.trim().isNotEmpty == true &&
                    !RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(value!.trim())
                ? AppSettingsScope.translate(
                    context,
                    "customer.use_country_code_and_digits_e_g_919876543210.542b2523",
                  )
                : null,
          ),
        ];
      case AccountSecurityAction.deleteAccount:
        final request = account.deletionRequest;
        return [
          Text(
            AppSettingsScope.translate(
              context,
              "customer.this_submits_an_account_deletion_request_for_.95771a70",
            ),
            style: TextStyle(height: 1.6),
          ),
          if (request != null) ...[
            const SizedBox(height: 16),
            Text(
              AppSettingsScope.translate(
                context,
                "customer.request_status_value0.5a58c83d",
                args: {"value0": request.label},
              ),
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
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.reason_optional.0f7d4664",
                ),
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
              title: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.i_want_to_request_deletion_of_my_eventor_acco.2c5d245f",
                ),
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
          if (request?.status == 'pending')
            TextButton(
              onPressed: _busy ? null : _cancelRequest,
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.cancel_deletion_request.c6869022",
                ),
              ),
            ),
          if (request?.status == 'in_review')
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.your_request_is_being_reviewed_contact_suppor.e54a9aab",
                ),
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(title: Text(_title)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF80152C)))
                else
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF0EDF0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF80152C).withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_account != null) ..._fields(),
                          if (_notice != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                _notice!,
                                style: const TextStyle(height: 1.5),
                              ),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFF80152C),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          if (_account == null)
                            TextButton(
                              onPressed: _load,
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "customer.retry.942087cc",
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (!activeDeletion &&
                              !(widget.action == AccountSecurityAction.email &&
                                  _emailSent))
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF80152C),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              onPressed: canSave ? _save : null,
                              child: Text(
                                _busy
                                    ? 'Please wait…'
                                    : widget.action ==
                                          AccountSecurityAction.deleteAccount
                                    ? 'Request deletion'
                                    : widget.action == AccountSecurityAction.email
                                    ? 'Update email'
                                    : 'Save',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
