import 'package:flutter/material.dart';

import 'customer_auth_screen.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});
  @override
  Widget build(BuildContext context) => const CustomerAuthScreen(signup: true);
}
