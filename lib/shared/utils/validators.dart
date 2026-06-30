import '../../core/constants/app_constants.dart';

class Validators {
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    final normalized = value.trim().toLowerCase();
    if (normalized.length < AppConstants.minUsernameLength ||
        normalized.length > AppConstants.maxUsernameLength) {
      return 'Username must be ${AppConstants.minUsernameLength}-${AppConstants.maxUsernameLength} characters';
    }
    final usernameRegex = RegExp(r'^[a-z][a-z0-9_]+$');
    if (!usernameRegex.hasMatch(normalized)) {
      return 'Use lowercase letters, numbers, underscores; start with a letter';
    }
    return null;
  }

  static String? emailOrUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email or username is required';
    final trimmed = value.trim();
    if (trimmed.contains('@')) return email(trimmed);
    return username(trimmed);
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? numeric(String? value, {String field = 'Value'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    if (double.tryParse(value) == null) return 'Enter a valid number';
    return null;
  }
}
