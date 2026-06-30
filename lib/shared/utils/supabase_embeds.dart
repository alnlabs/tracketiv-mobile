/// PostgREST embed hints when a table has multiple FKs to [profiles].
abstract final class SupabaseEmbeds {
  static const authorProfile =
      'profiles!author_id(display_name, username, avatar_url)';

  static const userProfile =
      'profiles!user_id(display_name, username, avatar_url)';

  /// Explicit columns — [logs] has FKs on both `author_id` and `deleted_by`.
  static const logColumns =
      'id, user_goal_id, author_id, log_date, value, note, created_at';

  static const logWithAuthor = '$logColumns, $authorProfile';

  static const commentWithAuthor = '*, $authorProfile';

  static const membershipWithUser = '*, $userProfile';
}
