enum FeedWidgetType { quote }

enum FeedWidgetQuoteSource { pool, custom }

enum FeedQuoteCategory {
  goal,
  life,
  community,
  motivation,
  mindfulness,
  success,
}

extension FeedQuoteCategoryX on FeedQuoteCategory {
  String get label => switch (this) {
        FeedQuoteCategory.goal => 'Goals',
        FeedQuoteCategory.life => 'Life',
        FeedQuoteCategory.community => 'Together',
        FeedQuoteCategory.motivation => 'Motivation',
        FeedQuoteCategory.mindfulness => 'Mindfulness',
        FeedQuoteCategory.success => 'Success',
      };

  static const allValues = FeedQuoteCategory.values;

  static String summaryLabel(Set<FeedQuoteCategory> selected, {required bool mixAll}) {
    if (mixAll || selected.isEmpty) return 'Mix of all topics';
    if (selected.length == 1) return selected.first.label;
    final names = selected.map((c) => c.label).toList()..sort();
    return names.join(', ');
  }
}

class FeedWidgetQuoteConfig {
  const FeedWidgetQuoteConfig({
    this.source = FeedWidgetQuoteSource.pool,
    this.text,
    this.author,
    this.category = FeedQuoteCategory.goal,
    this.categories = const {},
    this.mixAllTopics = true,
  });

  final FeedWidgetQuoteSource source;
  final String? text;
  final String? author;

  /// Legacy single category — used when [categories] is empty and [mixAllTopics] is false.
  final FeedQuoteCategory category;

  /// Selected pool topics. Empty with [mixAllTopics] true = random from entire pool.
  final Set<FeedQuoteCategory> categories;

  final bool mixAllTopics;

  bool get isOwnQuote => source == FeedWidgetQuoteSource.custom;

  bool get isPickedDaily => source == FeedWidgetQuoteSource.pool;

  Set<FeedQuoteCategory> get effectiveCategories {
    if (mixAllTopics || categories.isEmpty) return const {};
    return categories;
  }

  String get topicsSummary => isOwnQuote
      ? 'Your words'
      : FeedQuoteCategoryX.summaryLabel(categories, mixAll: mixAllTopics);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'source': source.name,
    };
    if (isOwnQuote) {
      if (text != null && text!.trim().isNotEmpty) map['text'] = text!.trim();
      if (author != null && author!.trim().isNotEmpty) {
        map['author'] = author!.trim();
      }
      map['category'] = category.name;
    } else if (mixAllTopics || categories.isEmpty) {
      // Omit categories — server picks from full pool.
    } else if (categories.length == 1) {
      map['category'] = categories.first.name;
      map['categories'] = categories.map((c) => c.name).toList();
    } else {
      map['categories'] = categories.map((c) => c.name).toList();
    }
    return map;
  }

  factory FeedWidgetQuoteConfig.fromJson(Map<String, dynamic> json) {
    final sourceName = json['source'] as String? ?? 'pool';
    final source = FeedWidgetQuoteSource.values.byName(sourceName);

    if (source == FeedWidgetQuoteSource.custom) {
      final categoryName = json['category'] as String? ?? 'goal';
      return FeedWidgetQuoteConfig(
        source: source,
        text: json['text'] as String?,
        author: json['author'] as String?,
        category: FeedQuoteCategory.values.byName(categoryName),
      );
    }

    final parsedCategories = <FeedQuoteCategory>{};
    final categoriesRaw = json['categories'];
    if (categoriesRaw is List) {
      for (final entry in categoriesRaw) {
        if (entry is String) {
          try {
            parsedCategories.add(FeedQuoteCategory.values.byName(entry));
          } catch (_) {}
        }
      }
    }

    if (parsedCategories.isNotEmpty) {
      return FeedWidgetQuoteConfig(
        source: source,
        categories: parsedCategories,
        mixAllTopics: false,
      );
    }

    final legacyCategory = json['category'] as String?;
    if (legacyCategory != null && legacyCategory.isNotEmpty) {
      return FeedWidgetQuoteConfig(
        source: source,
        category: FeedQuoteCategory.values.byName(legacyCategory),
        categories: {FeedQuoteCategory.values.byName(legacyCategory)},
        mixAllTopics: false,
      );
    }

    return const FeedWidgetQuoteConfig(
      source: FeedWidgetQuoteSource.pool,
      mixAllTopics: true,
    );
  }
}

class FeedWidget {
  const FeedWidget({
    required this.id,
    this.userId,
    this.groupId,
    this.groupName,
    required this.widgetType,
    required this.enabled,
    required this.showTime,
    required this.timezone,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? userId;
  final String? groupId;
  final String? groupName;
  final FeedWidgetType widgetType;
  final bool enabled;
  final String showTime;
  final String timezone;
  final FeedWidgetQuoteConfig config;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPersonal => userId != null;
  bool get isGroup => groupId != null;

  String get title => switch (widgetType) {
        FeedWidgetType.quote => 'Daily quote',
      };

  String get scopeSubtitle {
    if (isGroup) return groupName ?? 'Group';
    return 'Personal feed';
  }

  String get scopeLabel {
    if (isGroup) return groupName ?? 'Group';
    return 'Personal feed';
  }

  factory FeedWidget.fromJson(Map<String, dynamic> json) {
    final configRaw = json['config'];
    final configMap = configRaw is Map<String, dynamic>
        ? configRaw
        : (configRaw is Map ? Map<String, dynamic>.from(configRaw) : <String, dynamic>{});

    return FeedWidget(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      groupId: json['group_id'] as String?,
      groupName: json['group_name'] as String?,
      widgetType: FeedWidgetType.values.byName(json['widget_type'] as String),
      enabled: json['enabled'] as bool? ?? true,
      showTime: json['show_time'] as String? ?? '06:00:00',
      timezone: json['timezone'] as String? ?? 'UTC',
      config: FeedWidgetQuoteConfig.fromJson(configMap),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class FeedWidgetPayload {
  const FeedWidgetPayload({
    required this.text,
    required this.author,
    required this.category,
  });

  final String text;
  final String author;
  final FeedQuoteCategory category;

  String get categoryLabel => category.label;

  factory FeedWidgetPayload.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String? ?? 'goal';
    FeedQuoteCategory category;
    try {
      category = FeedQuoteCategory.values.byName(categoryName);
    } catch (_) {
      category = FeedQuoteCategory.goal;
    }
    return FeedWidgetPayload(
      text: json['text'] as String? ?? '',
      author: json['author'] as String? ?? 'Tracketiv',
      category: category,
    );
  }
}
