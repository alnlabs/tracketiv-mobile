import 'package:flutter/material.dart';

import '../utils/api_error_formatter.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.fallback = ApiErrorFormatter.defaultMessage,
  }) : assert(error != null || message != null);

  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final String fallback;

  String get _displayMessage =>
      message ?? ApiErrorFormatter.format(error, fallback: fallback);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_displayMessage, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
