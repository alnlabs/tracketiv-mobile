import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';

/// Wraps all admin routes with a separate theme and visual identity.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.light,
      child: ColoredBox(
        color: AdminTheme.light.scaffoldBackgroundColor ?? AdminTheme.light.colorScheme.surface,
        child: child,
      ),
    );
  }
}
