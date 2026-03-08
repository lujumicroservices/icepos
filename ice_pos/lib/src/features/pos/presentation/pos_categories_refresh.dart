import 'package:flutter_riverpod/legacy.dart';

/// Increment this when categories are added, edited, or deleted (e.g. from Category Management).
/// POS screen providers that depend on categories list will refetch when this changes.
final posCategoriesRefreshProvider = StateProvider<int>((ref) => 0);
