import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/offline_write_exception.dart';

/// Maps API/network exceptions to short, user-safe messages.
class ApiErrorFormatter {
  ApiErrorFormatter._();

  static const defaultMessage = 'Something went wrong. Please try again.';

  static String format(
    Object? error, {
    String fallback = defaultMessage,
  }) {
    if (error == null) return fallback;

    if (error is OfflineWriteException) {
      return OfflineWriteException.message;
    }

    if (error is OfflineCacheMissException) {
      return error.message;
    }

    if (error is AuthException) {
      return _cleanMessage(error.message, fallback);
    }

    if (error is PostgrestException) {
      return _fromPostgrest(error, fallback);
    }

    if (error is StorageException) {
      return _cleanMessage(error.message, fallback);
    }

    if (error is SocketException || isNetworkError(error)) {
      return 'Network error. Check your connection and try again.';
    }

    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }

    final text = error.toString();
    if (_looksTechnical(text)) {
      if (kDebugMode) {
        debugPrint('ApiErrorFormatter: $error');
      }
      return fallback;
    }

    return _cleanMessage(text, fallback);
  }

  static bool isNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('connection refused') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection reset');
  }

  static bool _looksTechnical(String text) {
    final lower = text.toLowerCase();
    return lower.contains('stack trace') ||
        lower.contains('package:') ||
        text.startsWith('#0') ||
        lower.contains('postgrestexception') ||
        lower.contains('authretryablefetchexception') ||
        lower.contains('functionsexception') ||
        text.length > 160;
  }

  static String _fromPostgrest(PostgrestException error, String fallback) {
    switch (error.code) {
      case '23505':
        final details = '${error.message} ${error.details ?? ''}'.toLowerCase();
        if (details.contains('log') || details.contains('user_goal_id')) {
          return 'You already have a log for this day on this goal.';
        }
        return 'That value is already in use.';
      case '42501':
        return 'You do not have permission to do that.';
      case 'PGRST116':
        return 'The requested item was not found.';
      case 'PGRST301':
        return 'Your session expired. Please sign in again.';
      default:
        final message = error.message.trim();
        if (message.isNotEmpty && !_looksTechnical(message)) {
          return _cleanMessage(message, fallback);
        }
        return fallback;
    }
  }

  static String _cleanMessage(String? raw, String fallback) {
    if (raw == null || raw.trim().isEmpty) return fallback;

    var message = raw.trim();
    message = message.replaceFirst(RegExp(r'^Exception:\s*'), '');
    message = message.replaceFirst(RegExp(r'^AuthException:\s*'), '');
    message = message.replaceFirst(RegExp(r'^PostgrestException:\s*'), '');
    message = message.replaceFirst(RegExp(r'^StorageException:\s*'), '');

    if (_looksTechnical(message) || message.length > 160) {
      return fallback;
    }
    return message;
  }
}

extension UserFacingApiError on Object {
  String toUserMessage({String fallback = ApiErrorFormatter.defaultMessage}) {
    return ApiErrorFormatter.format(this, fallback: fallback);
  }
}
