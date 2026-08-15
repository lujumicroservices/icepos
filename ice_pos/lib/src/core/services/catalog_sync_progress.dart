/// Progress report for [CloudSyncService.syncFromCloud].
class CatalogSyncProgress {
  const CatalogSyncProgress({
    required this.step,
    required this.totalSteps,
    required this.stageKey,
    this.detail,
  });

  /// 1-based current step.
  final int step;
  final int totalSteps;

  /// Stable key for l10n (e.g. `syncStepDownloadingProducts`).
  final String stageKey;

  /// Optional extra line (counts, retry, etc.).
  final String? detail;

  double get fraction {
    if (totalSteps <= 0) return 0;
    return (step / totalSteps).clamp(0.0, 1.0);
  }

  String get stepLabel => '$step / $totalSteps';
}
