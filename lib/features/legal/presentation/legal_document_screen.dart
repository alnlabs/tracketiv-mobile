import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/scaffold_layout.dart';
import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../content/legal_content.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
    this.footer,
  });

  final String title;
  final List<LegalSection> sections;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: TracketivAppBar(title: title),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          listScrollBottomPadding(context),
        ),
        children: [
          for (final section in sections) ...[
            if (section.heading != null) ...[
              Text(
                section.heading!,
                style: AppTypography.cardTitle(context, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              section.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 20),
          ],
          Wrap(
            spacing: 4,
            runSpacing: 0,
            alignment: WrapAlignment.center,
            children: [
              if (title != 'About') _LegalLink(label: 'About', path: '/about'),
              if (title != 'Disclaimer')
                _LegalLink(label: 'Disclaimer', path: '/disclaimer'),
              if (title != 'Privacy Policy')
                _LegalLink(label: 'Privacy Policy', path: '/privacy-policy'),
            ],
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.push(path),
      child: Text(label),
    );
  }
}
