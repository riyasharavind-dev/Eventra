import '../../utils/customer_contact_phone.dart';

import 'package:flutter/material.dart';

import '../../repositories/auth_repository.dart';
import '../../utils/auth_error_message.dart';
import '../../widgets/auth/customer_auth_layout.dart';
import 'account_recovery_screen.dart';

class CustomerAuthScreen extends StatefulWidget {
  const CustomerAuthScreen({super.key, this.signup = false, this.repository});
  final bool signup;
  final AuthRepository? repository;
  @override
  State<CustomerAuthScreen> createState() => _CustomerAuthState();
}

class _CustomerAuthState extends State<CustomerAuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController();
  late bool signup = widget.signup;
  late final repo = widget.repository ?? AuthRepository();
  bool busy = false, obscure = true;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  void switchMode() {
    if (busy) return;
    setState(() {
      signup = !signup;
      password.clear();
      form.currentState?.reset();
    });
  }

  void success() {
    if (mounted && Navigator.canPop(context)) Navigator.pop(context, true);
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      if (signup) {
        final contact = customerContactPhone(phone.text)!;
        final result = await repo.signUp(
          name: name.text.trim(),
          email: email.text.trim(),
          password: password.text,
          phone: contact,
        );
        if (!mounted) return;
        if (result.session == null) {
          setState(() {
            signup = false;
            password.clear();
          });
          message(
            authText(
              context,
              'Account created. Verify the email sent to you, then sign in.',
              'கணக்கு உருவாக்கப்பட்டது. மின்னஞ்சலைச் சரிபார்த்த பிறகு உள்நுழையவும்.',
            ),
          );
        } else {
          await repo.validateAccountRole();
          success();
        }
      } else {
        await repo.signIn(email: email.text.trim(), password: password.text);
        success();
      }
    } catch (e) {
      message(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: CustomerAuthLayout(
      onBack: busy ? () {} : () => Navigator.maybePop(context),
      child: AutofillGroup(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EventorAuthBrand(),
              const SizedBox(height: 23),
              AuthHeroIcon(signup: signup),
              const SizedBox(height: 13),
              Text(
                authText(
                  context,
                  signup ? 'Create Account' : 'Welcome Back',
                  signup ? 'கணக்கை உருவாக்கு' : 'மீண்டும் வருக',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17171B),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                authText(
                  context,
                  signup
                      ? 'Services and celebrations, all in one place. Start your event with ease.'
                      : 'Login to find services, manage your bookings and create special moments.',
                  signup
                      ? 'சேவைகளும் கொண்டாட்டங்களும் ஒரே இடத்தில். உங்கள் நிகழ்ச்சியை எளிதாகத் தொடங்குங்கள்.'
                      : 'சேவைகளைத் தேடவும், முன்பதிவுகளை நிர்வகிக்கவும் உள்நுழையுங்கள்.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF73737D),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 25),
              if (signup) ...[
                TextFormField(
                  key: const ValueKey('auth-name'),
                  controller: name,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  decoration: authField(
                    authText(context, 'Full Name', 'முழுப் பெயர்'),
                    Icons.person_outline,
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 2
                      ? authText(
                          context,
                          'Enter your full name',
                          'முழுப் பெயரை உள்ளிடவும்',
                        )
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const ValueKey('auth-email'),
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: authField(
                  authText(context, 'Email Address', 'மின்னஞ்சல் முகவரி'),
                  Icons.mail_outline_rounded,
                ),
                validator: (v) =>
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : authText(
                        context,
                        'Enter a valid email',
                        'சரியான மின்னஞ்சலை உள்ளிடவும்',
                      ),
              ),
              const SizedBox(height: 12),
              if (signup) ...[
                TextFormField(
                  key: const ValueKey('auth-phone'),
                  controller: phone,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.next,
                  decoration: authField(
                    authText(
                      context,
                      'Phone Number (+91)',
                      'தொலைபேசி எண் (+91)',
                    ),
                    Icons.phone_outlined,
                  ),
                  validator: (v) {
                    return customerContactPhone(v ?? '') != null
                        ? null
                        : authText(
                            context,
                            'Enter a valid contact number',
                            'சரியான தொடர்பு எண்ணை உள்ளிடவும்',
                          );
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const ValueKey('auth-password'),
                controller: password,
                enabled: !busy,
                obscureText: obscure,
                autofillHints: [
                  signup ? AutofillHints.newPassword : AutofillHints.password,
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submit(),
                decoration: authField(
                  authText(context, 'Password', 'கடவுச்சொல்'),
                  Icons.lock_outline_rounded,
                  suffix: IconButton(
                    tooltip: authText(
                      context,
                      'Show or hide password',
                      'கடவுச்சொல்லைக் காட்டு / மறை',
                    ),
                    onPressed: busy
                        ? null
                        : () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                    ),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty
                    ? authText(
                        context,
                        'Enter your password',
                        'கடவுச்சொல்லை உள்ளிடவும்',
                      )
                    : signup && (v?.length ?? 0) < 8
                    ? authText(
                        context,
                        'Use at least 8 characters',
                        'குறைந்தது 8 எழுத்துகளைப் பயன்படுத்தவும்',
                      )
                    : null,
              ),
              if (!signup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountRecoveryScreen(),
                            ),
                          ),
                    child: Text(
                      authText(
                        context,
                        'Forgot Password?',
                        'கடவுச்சொல்லை மறந்துவிட்டீர்களா?',
                      ),
                      style: const TextStyle(
                        color: authWine,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: authWine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: busy ? null : submit,
                  child: Text(
                    authText(
                      context,
                      busy
                          ? 'Please wait…'
                          : signup
                          ? 'Sign Up'
                          : 'Login',
                      busy
                          ? 'சற்று காத்திருக்கவும்…'
                          : signup
                          ? 'பதிவு செய்'
                          : 'உள்நுழை',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    authText(
                      context,
                      signup
                          ? 'Already have an account?'
                          : 'Don’t have an account?',
                      signup ? 'ஏற்கனவே கணக்கு உள்ளதா?' : 'கணக்கு இல்லையா?',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7A6B73),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : switchMode,
                    child: Text(
                      authText(
                        context,
                        signup ? 'Login' : 'Sign Up',
                        signup ? 'உள்நுழை' : 'பதிவு செய்',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: authWine,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
