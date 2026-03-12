import 'package:flutter/foundation.dart';

/// Call when showing an error in the UI so it also appears in the terminal for copying.
void logErrorToConsole(Object error, [StackTrace? stackTrace]) {
  const sep = '══════════════════════════════════════════════════════════';
  debugPrint(sep);
  debugPrint('ERROR (puedes copiar desde aquí):');
  debugPrint(sep);
  debugPrint(error.toString());
  if (stackTrace != null) {
    debugPrint('');
    debugPrint('Stack trace:');
    debugPrint(stackTrace.toString());
  }
  debugPrint(sep);
}
