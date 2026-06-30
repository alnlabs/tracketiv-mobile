import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/feed_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/feed_widget_repository.dart';

final feedWidgetRepositoryProvider = Provider<FeedWidgetRepository>((ref) {
  return FeedWidgetRepository(ref.watch(supabaseClientProvider));
});

final myFeedWidgetsProvider = FutureProvider<List<FeedWidget>>((ref) {
  return ref.watch(feedWidgetRepositoryProvider).listMyFeedWidgets();
});

final personalQuoteWidgetProvider = FutureProvider<FeedWidget?>((ref) async {
  final widgets = await ref.watch(myFeedWidgetsProvider.future);
  for (final w in widgets) {
    if (w.isPersonal && w.widgetType == FeedWidgetType.quote) return w;
  }
  return null;
});

final groupQuoteWidgetProvider =
    FutureProvider.family<FeedWidget?, String>((ref, groupId) async {
  final widgets = await ref.watch(myFeedWidgetsProvider.future);
  for (final w in widgets) {
    if (w.groupId == groupId && w.widgetType == FeedWidgetType.quote) return w;
  }
  return null;
});
