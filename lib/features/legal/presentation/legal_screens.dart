import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_version_label.dart';
import '../content/legal_content.dart';
import 'legal_document_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentScreen(
      title: 'About',
      sections: LegalContent.about,
      footer: const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 16),
        child: AppVersionLabel(),
      ),
    );
  }
}

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Disclaimer',
      sections: LegalContent.disclaimer,
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Privacy Policy',
      sections: LegalContent.privacyPolicy,
    );
  }
}

/// Footer links for auth screens.
class AuthLegalLinks extends StatelessWidget {
  const AuthLegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.push('/about'),
          child: const Text('About'),
        ),
        TextButton(
          onPressed: () => context.push('/disclaimer'),
          child: const Text('Disclaimer'),
        ),
        TextButton(
          onPressed: () => context.push('/privacy-policy'),
          child: const Text('Privacy'),
        ),
      ],
    );
  }
}
