import 'package:flutter/material.dart';

/// Bottom inset so list content is not hidden behind a [FloatingActionButton].
double fabScrollBottomPadding(BuildContext context, {double base = 16}) {
  return base + kFloatingActionButtonMargin + 56;
}

/// Bottom inset for scrollables (safe area / home indicator).
double listScrollBottomPadding(BuildContext context, {double base = 16}) {
  return base + MediaQuery.viewPaddingOf(context).bottom;
}
