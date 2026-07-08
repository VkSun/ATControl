import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueView<T> extends ConsumerWidget {
  final AsyncValue<T> value;
  final ProviderOrFamily? onRetry;
  final Widget Function(T data) builder;

  const AsyncValueView({
    super.key,
    required this.value,
    this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      // LimitedBox: bounded parent (Expanded) → no limit, Center fills height;
      //             unbounded parent (Column min) → limits to 80px, Center bounded.
      loading: () => const LimitedBox(
        maxHeight: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => LimitedBox(
        maxHeight: 200,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ошибка: $e', style: const TextStyle(fontSize: 12)),
                if (onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(onRetry!),
                    child: const Text('Повторить'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      data: builder,
    );
  }
}
