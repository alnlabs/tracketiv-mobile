import 'package:flutter/material.dart';

import '../utils/validators.dart';

/// Shared email/username + password fields for user and admin login screens.
class AuthCredentialFields extends StatelessWidget {
  const AuthCredentialFields({
    super.key,
    required this.identifierController,
    required this.passwordController,
    this.identifierLabel = 'Email or username',
    this.passwordLabel = 'Password',
  });

  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final String identifierLabel;
  final String passwordLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: identifierController,
          decoration: InputDecoration(labelText: identifierLabel),
          autocorrect: false,
          validator: Validators.emailOrUsername,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          decoration: InputDecoration(labelText: passwordLabel),
          obscureText: true,
          validator: Validators.password,
        ),
      ],
    );
  }
}
