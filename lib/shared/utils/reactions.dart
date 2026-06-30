import '../../core/constants/app_constants.dart';

/// Single source for reaction types, emojis, and labels across the app.
class Reactions {
  Reactions._();

  static List<String> get types => AppConstants.reactionTypes;

  static String emoji(String type) => AppConstants.reactionEmojis[type] ?? '👍';

  static String label(String type) => AppConstants.reactionLabels[type] ?? type;
}
