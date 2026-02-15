// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(posRepository)
final posRepositoryProvider = PosRepositoryProvider._();

final class PosRepositoryProvider
    extends $FunctionalProvider<PosRepository, PosRepository, PosRepository>
    with $Provider<PosRepository> {
  PosRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'posRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$posRepositoryHash();

  @$internal
  @override
  $ProviderElement<PosRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PosRepository create(Ref ref) {
    return posRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PosRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PosRepository>(value),
    );
  }
}

String _$posRepositoryHash() => r'4a596cb92243b06a28f8440c979f5d88d5ce714a';
