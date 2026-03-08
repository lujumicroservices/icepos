import 'package:ice_pos/src/features/pos/domain/category.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_navigation_controller.g.dart';

/// State for category breadcrumb navigation (e.g. [Home, Bebidas, Barra Fría]).
/// [breadcrumbs] is empty at root (Home); each item is a selected category in order.
class CategoryNavigationState {
  const CategoryNavigationState({this.breadcrumbs = const []});

  final List<Category> breadcrumbs;

  /// Id of the current category (last in breadcrumbs), or null if at root.
  int? get currentCategoryId =>
      breadcrumbs.isEmpty ? null : breadcrumbs.last.id;

  CategoryNavigationState copyWith({List<Category>? breadcrumbs}) {
    return CategoryNavigationState(
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
    );
  }
}

/// Controls category/subcategory navigation: breadcrumbs, go home, push, back.
@riverpod
class CategoryNavigationController extends _$CategoryNavigationController {
  @override
  CategoryNavigationState build() => const CategoryNavigationState();

  void goHome() {
    state = const CategoryNavigationState();
  }

  void pushCategory(Category category) {
    state = state.copyWith(
      breadcrumbs: [...state.breadcrumbs, category],
    );
  }

  void goBack() {
    if (state.breadcrumbs.isEmpty) return;
    state = state.copyWith(
      breadcrumbs: state.breadcrumbs.sublist(0, state.breadcrumbs.length - 1),
    );
  }

  /// Navigate to a specific breadcrumb index (e.g. click "Home" -> index 0).
  void goToBreadcrumbIndex(int index) {
    if (index < 0 || index >= state.breadcrumbs.length) return;
    state = state.copyWith(
      breadcrumbs: state.breadcrumbs.sublist(0, index + 1),
    );
  }
}
