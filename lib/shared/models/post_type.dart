import 'package:flutter/material.dart';

enum PostType {
  metric,
  note,
  checkIn;

  static PostType? fromQuery(String? value) {
    switch (value) {
      case 'metric':
        return PostType.metric;
      case 'note':
        return PostType.note;
      case 'checkin':
        return PostType.checkIn;
      default:
        return null;
    }
  }
}

extension PostTypeX on PostType {
  String get label {
    switch (this) {
      case PostType.metric:
        return 'Log progress';
      case PostType.note:
        return 'Share update';
      case PostType.checkIn:
        return 'Quick check-in';
    }
  }

  String get subtitle {
    switch (this) {
      case PostType.metric:
        return 'Record a number — weight, steps, water, etc.';
      case PostType.note:
        return 'Post a text update to your feed';
      case PostType.checkIn:
        return 'Mark today as done for a goal';
    }
  }

  IconData get icon {
    switch (this) {
      case PostType.metric:
        return Icons.show_chart_outlined;
      case PostType.note:
        return Icons.edit_note_outlined;
      case PostType.checkIn:
        return Icons.check_circle_outline;
    }
  }

  String get queryValue {
    switch (this) {
      case PostType.metric:
        return 'metric';
      case PostType.note:
        return 'note';
      case PostType.checkIn:
        return 'checkin';
    }
  }
}
