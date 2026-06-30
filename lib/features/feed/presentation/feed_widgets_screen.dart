import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../widgets/feed_widgets_body.dart';

class FeedWidgetsScreen extends ConsumerWidget {
  const FeedWidgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      appBar: TracketivAppBar(
        title: 'Add-ons',
        subtitle: 'Install extras for your feed',
      ),
      body: FeedWidgetsBody(),
    );
  }
}
