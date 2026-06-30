class AppConstants {
  static const appName = 'Tracketiv';
  static const minPasswordLength = 8;
  static const minUsernameLength = 3;
  static const maxUsernameLength = 30;
  static const reactionTypes = [
    'like',
    'love',
    'celebrate',
    'cheer',
    'fire',
    'support',
    'star',
    'clap',
    'hundred',
    'rocket',
    'wow',
    'laugh',
  ];

  static const reactionEmojis = {
    'like': '👍',
    'love': '❤️',
    'celebrate': '🎉',
    'cheer': '🙌',
    'fire': '🔥',
    'support': '💪',
    'star': '⭐',
    'clap': '👏',
    'hundred': '💯',
    'rocket': '🚀',
    'wow': '😮',
    'laugh': '😂',
  };

  static const reactionLabels = {
    'like': 'Like',
    'love': 'Love',
    'celebrate': 'Celebrate',
    'cheer': 'Cheer',
    'fire': 'On fire',
    'support': 'Support',
    'star': 'Star',
    'clap': 'Clap',
    'hundred': 'Perfect',
    'rocket': 'Rocket',
    'wow': 'Wow',
    'laugh': 'Laugh',
  };

  static const feedbackEmail = 'alnlabs.com@gmail.com';
  static const feedbackTypes = ['suggestion', 'improvement', 'issue'];
  static const feedbackTypeLabels = {
    'suggestion': 'Suggestion',
    'improvement': 'Improvement',
    'issue': 'Issue',
  };
}
