import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Caches device connectivity for synchronous checks (e.g. [OfflineWritePolicy]).
/// Call [init] once at app startup after [WidgetsFlutterBinding.ensureInitialized].
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Last known state: any non-[ConnectivityResult.none] interface.
  bool get isConnected => _isConnected;

  Stream<bool> get onConnectivityChanged => _controller.stream;

  static bool _listConnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> init() async {
    try {
      final first = await _connectivity.checkConnectivity();
      _apply(first);
    } catch (e) {
      debugPrint('ConnectivityService.init: $e');
      _isConnected = true;
    }
    _sub ??= _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final connected = _listConnected(results);
    if (_isConnected != connected) {
      _isConnected = connected;
      _controller.add(connected);
      debugPrint('ConnectivityService: connected=$connected');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
