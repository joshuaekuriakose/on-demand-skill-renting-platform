import 'package:flutter/material.dart';

import '../widgets/app_card.dart';

/// Standard view for async states.
///
/// This keeps loading/empty/error presentation consistent across screens.
class AsyncStateView<T> extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final T? data;
  final String? emptyMessage;

  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.data,
    required this.builder,
    this.errorMessage,
    this.emptyMessage,
    this.onRetry,
  });

  bool _isEmpty(T? value) {
    if (value == null) return true;
    if (value is Iterable) return (value as Iterable).isEmpty;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Center(
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text("Retry"),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (_isEmpty(data)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage ?? "No data available",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return builder(context, data as T);
  }
}

