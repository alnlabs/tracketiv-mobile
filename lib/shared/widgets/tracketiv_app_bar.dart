import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// App bar with an explicit page title style so it always outranks card titles.
class TracketivAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TracketivAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.isLoading = false,
    this.bottom,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool isLoading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    var height = subtitle != null ? 64.0 : kToolbarHeight;
    if (isLoading) height += 3;
    if (bottom != null) height += bottom!.preferredSize.height;
    return Size.fromHeight(height);
  }

  @override
  Widget build(BuildContext context) {
    final titleContent = titleWidget ??
        Text(
          title!,
          style: AppTypography.appBarTitle(context),
        );

    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      title: subtitle == null
          ? titleContent
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleContent,
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.appBarSubtitle(context),
                ),
              ],
            ),
      actions: actions,
      bottom: isLoading
          ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(minHeight: 3),
            )
          : bottom,
    );
  }
}
