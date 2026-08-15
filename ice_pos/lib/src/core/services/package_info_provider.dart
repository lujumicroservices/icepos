import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Cached for the app process so the drawer does not rebuild [PackageInfo.fromPlatform]
/// on every frame (which can show stale or flickering version text).
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});
