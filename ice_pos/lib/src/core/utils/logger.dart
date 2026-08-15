import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/services/operation_log_sink.dart';

/// Observer that logs provider updates for visibility and debugging.
final class RiverpodLogger extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final name = context.provider.name ?? context.provider.runtimeType.toString();
    debugPrint('Riverpod provider failed: $name — $error');
    unawaited(OperationLogSink.report(
      level: 'error',
      operation: 'riverpod_provider',
      message: error.toString(),
      context: {'provider': name},
      stackTrace: stackTrace,
    ));
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    final providerName =
        context.provider.name ?? context.provider.runtimeType.toString();
    debugPrint('');
    debugPrint('┌─ Provider updated: $providerName');
    debugPrint('│');
    debugPrint('│  OLD: ${_formatValue(previousValue)}');
    debugPrint('│');
    debugPrint('│  NEW: ${_formatValue(newValue)}');
    debugPrint('└─');
    debugPrint('');
  }

  String _formatValue(Object? value) {
    if (value == null) return 'null';

    final str = value.toString();
    const maxLength = 200;

    if (str.length <= maxLength) {
      return str.replaceAll('\n', ' ').trim();
    }

    return '${str.substring(0, maxLength).replaceAll('\n', ' ').trim()}...';
  }
}
