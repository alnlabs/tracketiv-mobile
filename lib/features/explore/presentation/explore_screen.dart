import 'package:flutter/material.dart';

import '../../../shared/widgets/tracketiv_app_bar.dart';
import '../../connections/widgets/connections_body.dart';
import '../../feed/widgets/feed_widgets_body.dart';
import '../../goals/presentation/goal_catalog_screen.dart';

/// Explore hub: feed add-ons + connections + solo goal templates.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: TracketivAppBar(
          title: 'Explore',
          subtitle: 'Add-ons, friends & goals',
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.extension_outlined),
                text: 'Add-ons',
              ),
              Tab(
                icon: Icon(Icons.people_outline),
                text: 'Connect',
              ),
              Tab(
                icon: Icon(Icons.flag_outlined),
                text: 'Goals',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FeedWidgetsBody(),
            ConnectionsBody(),
            SoloGoalCatalogBody(),
          ],
        ),
      ),
    );
  }
}
