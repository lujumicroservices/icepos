import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';

/// Emits [true] when the device reports a network interface (not necessarily Supabase reachable).
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  await ConnectivityService.instance.init();
  yield ConnectivityService.instance.isConnected;
  yield* ConnectivityService.instance.onConnectivityChanged;
});
