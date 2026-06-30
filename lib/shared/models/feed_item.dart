import 'package:intl/intl.dart';

import '../utils/metric_utils.dart';
import 'feed_widget.dart';

enum FeedPostKind { metric, checkIn, note, unknown }

enum FeedItemType { log, widget }

enum LogValueTrend { up, down, flat, none }

class FeedItem {
  const FeedItem({
    required this.logId,
    required this.createdAt,
    required this.logDate,
    this.logValue,
    this.previousLogValue,
    this.goalStartValue,
    this.logNote,
    this.authorId,
    this.authorName,
    this.authorUsername,
    this.goalId,
    this.goalTitle,
    this.goalMode = 'solo',
    this.metricType,
    this.metricUnit,
    this.groupId,
    this.groupName,
    this.commentCount = 0,
    this.itemType = FeedItemType.log,
    this.widgetType,
    this.widgetPayload,
    this.widgetUserId,
  });

  final String logId;
  final DateTime createdAt;
  final DateTime logDate;
  final double? logValue;
  final double? previousLogValue;
  final double? goalStartValue;
  final String? logNote;
  final String? authorId;
  final String? authorName;
  final String? authorUsername;
  final String? goalId;
  final String? goalTitle;
  final String goalMode;
  final String? metricType;
  final String? metricUnit;
  final String? groupId;
  final String? groupName;
  final int commentCount;
  final FeedItemType itemType;
  final String? widgetType;
  final FeedWidgetPayload? widgetPayload;
  final String? widgetUserId;

  bool get isWidget => itemType == FeedItemType.widget;
  bool get isLog => itemType == FeedItemType.log;
  bool get isPersonalWidget => isWidget && widgetUserId != null;

  bool get isGroup => groupId != null || goalMode == 'group';
  bool get isSolo => !isGroup;

  String get authorLabel =>
      authorName ?? (authorUsername != null ? '@$authorUsername' : 'User');

  String get authorInitial =>
      (authorName ?? authorUsername ?? 'U')[0].toUpperCase();

  String? get authorSubtitle {
    if (authorName != null &&
        authorUsername != null &&
        authorUsername!.isNotEmpty) {
      return '@$authorUsername';
    }
    return null;
  }

  bool get isCheckIn {
    if (logValue != null) return false;
    final note = logNote?.trim().toLowerCase() ?? '';
    return note.contains('checked in');
  }

  FeedPostKind get postKind {
    if (isWidget) return FeedPostKind.unknown;
    if (logValue != null) return FeedPostKind.metric;
    if (isCheckIn) return FeedPostKind.checkIn;
    if (logNote != null && logNote!.trim().isNotEmpty) return FeedPostKind.note;
    return FeedPostKind.unknown;
  }

  String? get userFacingNote {
    final note = logNote?.trim();
    if (note == null || note.isEmpty || isCheckIn) return null;
    return note;
  }

  String get formattedValue {
    if (logValue == null) return '';
    final unit = formattedUnitLabel;
    return unit.isEmpty ? formattedNumber : '$formattedNumber $unit';
  }

  String get formattedNumber {
    if (logValue == null) return '';
    final value = logValue!;
    return value == value.roundToDouble()
        ? NumberFormat.decimalPattern().format(value.toInt())
        : NumberFormat.decimalPattern().format(value);
  }

  String get formattedUnitLabel => MetricUtils.formatUnit(metricUnit);

  /// Previous log for same author+goal, or goal start value as fallback.
  double? get comparisonBaseline => previousLogValue ?? goalStartValue;

  bool get comparesToStartValue =>
      previousLogValue == null && goalStartValue != null;

  bool get hasValueComparison =>
      logValue != null && comparisonBaseline != null;

  double? get valueDelta {
    if (!hasValueComparison) return null;
    return logValue! - comparisonBaseline!;
  }

  String? get formattedDelta {
    final delta = valueDelta;
    if (delta == null || delta == 0) return null;
    final abs = delta.abs();
    final formatted = abs == abs.roundToDouble()
        ? NumberFormat.decimalPattern().format(abs.toInt())
        : NumberFormat.decimalPattern().format(abs);
    final sign = delta > 0 ? '+' : '−';
    final unit = formattedUnitLabel;
    return unit.isEmpty ? '$sign$formatted' : '$sign$formatted $unit';
  }

  String? get formattedDeltaPercent {
    final delta = valueDelta;
    final baseline = comparisonBaseline;
    if (delta == null || baseline == null || baseline == 0) {
      return null;
    }
    final pct = (delta / baseline.abs()) * 100;
    final sign = pct > 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  /// Stock-style change line, e.g. "+500 (+6.2%)" or "−2 (−1.5%)".
  String? get formattedChangeLine {
    if (!hasValueComparison) return null;
    if (valueDelta == 0) return '0 (0.0%)';
    final delta = formattedDelta;
    final pct = formattedDeltaPercent;
    if (delta == null) return null;
    if (pct != null) return '$delta ($pct)';
    return delta;
  }

  String? get formattedBaselineValue {
    final baseline = comparisonBaseline;
    if (baseline == null) return null;
    final formatted = baseline == baseline.roundToDouble()
        ? NumberFormat.decimalPattern().format(baseline.toInt())
        : NumberFormat.decimalPattern().format(baseline);
    final unit = formattedUnitLabel;
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  String get formattedBaselineLabel =>
      comparesToStartValue ? 'Start' : 'Prev';

  LogValueTrend get valueTrend {
    if (!hasValueComparison) return LogValueTrend.none;
    if (logValue! > comparisonBaseline!) return LogValueTrend.up;
    if (logValue! < comparisonBaseline!) return LogValueTrend.down;
    return LogValueTrend.flat;
  }

  FeedItem copyWith({
    double? previousLogValue,
    double? goalStartValue,
    int? commentCount,
  }) {
    return FeedItem(
      logId: logId,
      createdAt: createdAt,
      logDate: logDate,
      logValue: logValue,
      previousLogValue: previousLogValue ?? this.previousLogValue,
      goalStartValue: goalStartValue ?? this.goalStartValue,
      logNote: logNote,
      authorId: authorId,
      authorName: authorName,
      authorUsername: authorUsername,
      goalId: goalId,
      goalTitle: goalTitle,
      goalMode: goalMode,
      metricType: metricType,
      metricUnit: metricUnit,
      groupId: groupId,
      groupName: groupName,
      commentCount: commentCount ?? this.commentCount,
      itemType: itemType,
      widgetType: widgetType,
      widgetPayload: widgetPayload,
      widgetUserId: widgetUserId,
    );
  }

  String get contextLabel {
    if (isGroup) {
      return groupName ?? 'Group goal';
    }
    return 'Solo goal';
  }

  bool get isBackdated {
    final today = DateTime.now();
    final logDay = DateTime(logDate.year, logDate.month, logDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return logDay.isBefore(todayDay);
  }

  String? get logDateLabel {
    if (!isBackdated) return null;
    return 'Logged for ${DateFormat.MMMd().format(logDate)}';
  }

  String activitySummary(FeedPostKind kind) {
    switch (kind) {
      case FeedPostKind.metric:
        return 'Logged progress';
      case FeedPostKind.checkIn:
        return 'Checked in';
      case FeedPostKind.note:
        return 'Shared an update';
      case FeedPostKind.unknown:
        return 'Posted an update';
    }
  }

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final itemTypeName = json['item_type'] as String? ?? 'log';
    FeedItemType itemType;
    try {
      itemType = FeedItemType.values.byName(itemTypeName);
    } catch (_) {
      itemType = FeedItemType.log;
    }

    final payloadRaw = json['widget_payload'];
    FeedWidgetPayload? widgetPayload;
    if (payloadRaw is Map<String, dynamic>) {
      widgetPayload = FeedWidgetPayload.fromJson(payloadRaw);
    } else if (payloadRaw is Map) {
      widgetPayload = FeedWidgetPayload.fromJson(Map<String, dynamic>.from(payloadRaw));
    }

    return FeedItem(
      logId: json['log_id'] as String,
      createdAt: _parseDateTime(json['created_at']),
      logDate: _parseDateTime(json['log_date']),
      logValue: (json['log_value'] as num?)?.toDouble(),
      previousLogValue: (json['previous_log_value'] as num?)?.toDouble(),
      goalStartValue: (json['goal_start_value'] as num?)?.toDouble(),
      logNote: json['log_note'] as String?,
      authorId: json['author_id'] as String?,
      authorName: json['author_name'] as String?,
      authorUsername: json['author_username'] as String?,
      goalId: json['goal_id'] as String?,
      goalTitle: json['goal_title'] as String?,
      goalMode: json['goal_mode'] as String? ?? 'solo',
      metricType: json['metric_type'] as String?,
      metricUnit: json['metric_unit'] as String?,
      groupId: json['group_id'] as String?,
      groupName: json['group_name'] as String?,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      itemType: itemType,
      widgetType: json['widget_type'] as String?,
      widgetPayload: widgetPayload,
      widgetUserId: json['widget_user_id'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.parse(raw.contains('T') ? raw : '${raw}T00:00:00');
    }
    throw FormatException('Invalid date: $raw');
  }
}
