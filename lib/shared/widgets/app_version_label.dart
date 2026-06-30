import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_version_provider.dart';

class AppVersionLabel extends ConsumerWidget {
  const AppVersionLabel({
    super.key,
    this.style,
    this.prefix = 'Version ',
  });

  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionLabelProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = style ??
        Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            );

    return versionAsync.when(
      loading: () => Text('$prefix…', style: textStyle, textAlign: TextAlign.center),
      error: (_, __) => const SizedBox.shrink(),
      data: (label) => Text(
        '$prefix$label',
        style: textStyle,
        textAlign: TextAlign.center,
      ),
    );
  }
}
