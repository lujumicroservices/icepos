// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_navigation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controls category/subcategory navigation: breadcrumbs, go home, push, back.

@ProviderFor(CategoryNavigationController)
final categoryNavigationControllerProvider =
    CategoryNavigationControllerProvider._();

/// Controls category/subcategory navigation: breadcrumbs, go home, push, back.
final class CategoryNavigationControllerProvider
    extends
        $NotifierProvider<
          CategoryNavigationController,
          CategoryNavigationState
        > {
  /// Controls category/subcategory navigation: breadcrumbs, go home, push, back.
  CategoryNavigationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryNavigationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryNavigationControllerHash();

  @$internal
  @override
  CategoryNavigationController create() => CategoryNavigationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryNavigationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryNavigationState>(value),
    );
  }
}

String _$categoryNavigationControllerHash() =>
    r'9a1cbc36ea15fd405420e56d229bf7dc1a584a78';

/// Controls category/subcategory navigation: breadcrumbs, go home, push, back.

abstract class _$CategoryNavigationController
    extends $Notifier<CategoryNavigationState> {
  CategoryNavigationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<CategoryNavigationState, CategoryNavigationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CategoryNavigationState, CategoryNavigationState>,
              CategoryNavigationState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
