import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/feed_widget.dart';
import '../../../shared/utils/json_utils.dart';

class FeedWidgetRepository {
  FeedWidgetRepository(this._client);

  final SupabaseClient _client;

  Future<List<FeedWidget>> listMyFeedWidgets() async {
    final data = await _client.rpc('list_my_feed_widgets');
    return asJsonList(data).map(FeedWidget.fromJson).toList();
  }

  Future<String> upsertFeedWidget({
    String? widgetId,
    String? userId,
    String? groupId,
    required FeedWidgetType widgetType,
    required bool enabled,
    required String showTime,
    required String timezone,
    required FeedWidgetQuoteConfig config,
  }) async {
    final data = await _client.rpc(
      'upsert_feed_widget',
      params: {
        'p_widget_id': widgetId,
        'p_user_id': userId,
        'p_group_id': groupId,
        'p_widget_type': widgetType.name,
        'p_enabled': enabled,
        'p_show_time': showTime,
        'p_timezone': timezone,
        'p_config': config.toJson(),
      },
    );
    return data as String;
  }
}
