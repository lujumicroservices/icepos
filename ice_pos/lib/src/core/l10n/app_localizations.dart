import 'package:flutter/material.dart';

/// Localized strings for the app. Default locale: Spanish (es).
class AppLocalizations {
  AppLocalizations(this.locale)
      : _strings = locale.languageCode == 'en' ? _en : _es;

  final Locale locale;
  final Map<String, String> _strings;

  String _(String key) => _strings[key] ?? key;

  // General
  String get appTitle => _('appTitle');
  String get menu => _('menu');
  String get language => _('language');
  String get languageNameEs => _('languageNameEs');
  String get languageNameEn => _('languageNameEn');
  String get cancel => _('cancel');
  String get done => _('done');
  String get close => _('close');
  String get apply => _('apply');
  String get ok => _('ok');
  String get error => _('error');

  // Cloud
  String get cloudActive => _('cloudActive');
  String get cloudNotConfigured => _('cloudNotConfigured');
  String get syncWithSupabase => _('syncWithSupabase');
  String get syncEnvHint => _('syncEnvHint');
  String get setupSupabaseTitle => _('setupSupabaseTitle');
  String get setupSupabaseSubtitle => _('setupSupabaseSubtitle');
  String get setupSupabaseUrlLabel => _('setupSupabaseUrlLabel');
  String get setupSupabaseAnonKeyLabel => _('setupSupabaseAnonKeyLabel');
  String get setupSupabaseConnect => _('setupSupabaseConnect');
  String get setupSupabaseSkip => _('setupSupabaseSkip');
  String get setupSupabaseSchemaNote => _('setupSupabaseSchemaNote');
  String get setupSupabaseInvalidUrl => _('setupSupabaseInvalidUrl');
  String get setupSupabaseConnecting => _('setupSupabaseConnecting');
  String get setupSupabaseError => _('setupSupabaseError');
  String get testConnection => _('testConnection');
  String get connectionOk => _('connectionOk');
  String get sync => _('sync');
  String get syncFromCloud => _('syncFromCloud');
  String get sendToCloud => _('sendToCloud');
  String get sendToCloudSubtitle => _('sendToCloudSubtitle');
  String get syncingFromCloud => _('syncingFromCloud');
  String get syncSuccess => _('syncSuccess');
  String get syncError => _('syncError');
  String get syncStepStarting => _('syncStepStarting');
  String get syncStepDownloadingCategories => _('syncStepDownloadingCategories');
  String get syncStepDownloadingProducts => _('syncStepDownloadingProducts');
  String get syncStepDownloadingRecipes => _('syncStepDownloadingRecipes');
  String get syncStepDownloadingBundles => _('syncStepDownloadingBundles');
  String get syncStepSavingLocal => _('syncStepSavingLocal');
  String get syncStepSavingCategories => _('syncStepSavingCategories');
  String get syncStepSavingProducts => _('syncStepSavingProducts');
  String get syncStepSavingRecipes => _('syncStepSavingRecipes');
  String get syncStepSavingBundles => _('syncStepSavingBundles');
  String get syncStepFinishing => _('syncStepFinishing');
  String syncStepProgress(String stepLabel) =>
      _('syncStepProgress').replaceAll('{step}', stepLabel);
  String catalogMenuCacheLastSync(String when) =>
      _('catalogMenuCacheLastSync').replaceAll('{when}', when);
  String get catalogMenuCacheNever => _('catalogMenuCacheNever');
  String get offlineBanner => _('offlineBanner');
  String get offlineRequiresInternet => _('offlineRequiresInternet');
  String get sendingToCloud => _('sendingToCloud');
  String get dataSentToCloud => _('dataSentToCloud');
  String get loadMenuFromJson => _('loadMenuFromJson');
  String get loadMenuFromJsonSubtitle => _('loadMenuFromJsonSubtitle');
  String get importRecipesFromJson => _('importRecipesFromJson');
  String get importRecipesFromJsonSubtitle => _('importRecipesFromJsonSubtitle');
  String get importRecipesConfirmTitle => _('importRecipesConfirmTitle');
  String get importRecipesConfirmBody => _('importRecipesConfirmBody');
  String get importRecipesPushCloudTitle => _('importRecipesPushCloudTitle');
  String get importRecipesPushCloudBody => _('importRecipesPushCloudBody');
  String get importRecipesPushCloudLocal => _('importRecipesPushCloudLocal');
  String get importRecipesPushCloudYes => _('importRecipesPushCloudYes');
  String get importingRecipes => _('importingRecipes');
  String get importRecipesDone => _('importRecipesDone');
  String get importRecipesReportPath => _('importRecipesReportPath');
  String get importRecipesReportClipboard => _('importRecipesReportClipboard');
  String get loadingMenuFromJson => _('loadingMenuFromJson');
  String get loadingMenuAndSending => _('loadingMenuAndSending');
  String get menuReloaded => _('menuReloaded');
  String get reloadMenuConfirmTitle => _('reloadMenuConfirmTitle');
  String get reloadMenuConfirmBody => _('reloadMenuConfirmBody');
  String get reload => _('reload');
  String get loadJsonNotAllowedTitle => _('loadJsonNotAllowedTitle');
  String get loadJsonNotAllowedBody => _('loadJsonNotAllowedBody');
  String get later => _('later');
  String get yesLoadAndSend => _('yesLoadAndSend');
  String get updateAvailable => _('updateAvailable');
  String get download => _('download');
  String get operationLogTitle => _('operationLogTitle');
  String get operationLogSubtitle => _('operationLogSubtitle');
  String get operationLogEmpty => _('operationLogEmpty');
  String get shiftCloseDiagnosticsTitle => _('shiftCloseDiagnosticsTitle');
  String get shiftCloseDiagnosticsMenuSubtitle => _('shiftCloseDiagnosticsMenuSubtitle');
  String get shiftCloseDiagnosticsSubtitle => _('shiftCloseDiagnosticsSubtitle');
  String get shiftCloseDiagnosticsEmpty => _('shiftCloseDiagnosticsEmpty');
  String get shiftCloseDiagnosticsDisabled => _('shiftCloseDiagnosticsDisabled');
  String get cloudPosDiagnosticsTitle => _('cloudPosDiagnosticsTitle');
  String get shiftCloseEventsTab => _('shiftCloseEventsTab');
  String get devicesAndClosuresTab => _('devicesAndClosuresTab');
  String get registerDeviceToCloudTitle => _('registerDeviceToCloudTitle');
  String get registerDeviceToCloudSubtitle => _('registerDeviceToCloudSubtitle');
  String get registerDeviceToCloudOk => _('registerDeviceToCloudOk');
  String get cloudDevicesEmpty => _('cloudDevicesEmpty');
  String get cloudDeviceLastSeen => _('cloudDeviceLastSeen');
  String get cloudDeviceOpenShift => _('cloudDeviceOpenShift');
  String get cloudDeviceNoOpenShift => _('cloudDeviceNoOpenShift');
  String get cloudRemoteCloseShift => _('cloudRemoteCloseShift');
  String get cloudRemoteCloseShiftHint => _('cloudRemoteCloseShiftHint');
  String get cloudSalesByDevice => _('cloudSalesByDevice');
  String get cloudClosuresByDevice => _('cloudClosuresByDevice');
  String get cloudShiftClosedRemoteOk => _('cloudShiftClosedRemoteOk');
  String get cloudNoSalesForDevice => _('cloudNoSalesForDevice');
  String get cloudNoClosuresForDevice => _('cloudNoClosuresForDevice');
  String get storeLabel => _('storeLabel');
  String get exportOperationLog => _('exportOperationLog');
  String get clearOperationLogConfirmTitle => _('clearOperationLogConfirmTitle');
  String get clearOperationLogConfirmBody => _('clearOperationLogConfirmBody');
  String get versionBuild => _('versionBuild');
  String get downloadHint => _('downloadHint');
  String get downloadLinkCopied => _('downloadLinkCopied');
  String get alreadyLatestVersion => _('alreadyLatestVersion');
  String get remoteUpdateRequestedTitle => _('remoteUpdateRequestedTitle');
  String get remoteUpdateRequestedBodyDefault => _('remoteUpdateRequestedBodyDefault');
  String get remoteUpdateCheckNow => _('remoteUpdateCheckNow');
  String get remoteUpdateAckLater => _('remoteUpdateAckLater');
  String get cloudRequestAppUpdate => _('cloudRequestAppUpdate');
  String get cloudRequestAppUpdateSubtitle => _('cloudRequestAppUpdateSubtitle');
  String get cloudClearUpdateRequest => _('cloudClearUpdateRequest');
  String get cloudUpdateRequestSent => _('cloudUpdateRequestSent');
  String get cloudUpdateRequestCleared => _('cloudUpdateRequestCleared');
  String get cloudUpdateRequestMessageHint => _('cloudUpdateRequestMessageHint');
  String get cloudUpdatePendingBadge => _('cloudUpdatePendingBadge');

  // Seguridad / roles / login
  String get login => _('login');
  String get username => _('username');
  String get emailOrUsername => _('emailOrUsername');
  String get password => _('password');
  String get signIn => _('signIn');
  String get invalidCredentials => _('invalidCredentials');
  String get logout => _('logout');
  String get logoutHint => _('logoutHint');
  String get adminAccess => _('adminAccess');
  String get adminAccessHint => _('adminAccessHint');
  String get enterAdminPin => _('enterAdminPin');
  String get setAdminPin => _('setAdminPin');
  String get invalidPin => _('invalidPin');
  String get lockAsEmployee => _('lockAsEmployee');
  String get lockAsEmployeeHint => _('lockAsEmployeeHint');
  String get salesToday => _('salesToday');
  String get employeeMode => _('employeeMode');

  // POS / Cart
  String get pointOfSale => _('pointOfSale');
  String get cart => _('cart');
  String get cartEmpty => _('cartEmpty');
  String get checkout => _('checkout');
  String get total => _('total');
  String get bundles => _('bundles');
  String get subtotalOther => _('subtotalOther');
  String get discount => _('discount');
  String get removeDiscount => _('removeDiscount');
  String get applyDiscount => _('applyDiscount');
  String get scanDiscount => _('scanDiscount');
  String get quickSearchHint => _('quickSearchHint');
  String get searchNoResults => _('searchNoResults');
  String get park => _('park');
  String get processingSale => _('processingSale');
  String get saleComplete => _('saleComplete');
  String get ticketSent => _('ticketSent');
  String get printError => _('printError');
  String get printingTicket => _('printingTicket');
  String get reprintTicket => _('reprintTicket');
  String get saleCompletePrintError => _('saleCompletePrintError');
  // Checkout dialog
  String get amountReceived => _('amountReceived');
  String get change => _('change');
  String get exactAmount => _('exactAmount');
  String get confirmSale => _('confirmSale');
  String get cash => _('cash');
  String get card => _('card');
  String get transfer => _('transfer');
  String get debit => _('debit');
  String get credit => _('credit');
  String get verifyTransfer => _('verifyTransfer');
  String get singlePayment => _('singlePayment');
  String get splitPayment => _('splitPayment');
  String get addPaymentMethod => _('addPaymentMethod');
  String get splitPaymentRemaining => _('splitPaymentRemaining');
  String get splitPaymentComplete => _('splitPaymentComplete');
  String get splitPaymentOverpaid => _('splitPaymentOverpaid');
  String get amount => _('amount');
  String get payment => _('payment');
  String get remove => _('remove');
  String get errorLoading => _('errorLoading');
  String get discountPercent => _('discountPercent');
  String get productDiscountLabel => _('productDiscountLabel');

  // Drawer
  String get supplyManagement => _('supplyManagement');
  String get productManagement => _('productManagement');
  String get categoryManagement => _('categoryManagement');
  String get categoryManagementSubtitle => _('categoryManagementSubtitle');
  String get webAdminHomeTitle => _('webAdminHomeTitle');
  String get webAdminHomeSubtitle => _('webAdminHomeSubtitle');
  String get webQuickAccess => _('webQuickAccess');
  String get drawerSectionGeneral => _('drawerSectionGeneral');
  String get drawerSectionDeviceCloud => _('drawerSectionDeviceCloud');
  String get drawerSectionCloudData => _('drawerSectionCloudData');
  String get drawerSectionCatalog => _('drawerSectionCatalog');
  String get drawerSectionSalesReports => _('drawerSectionSalesReports');
  String get drawerSectionOrganization => _('drawerSectionOrganization');
  String get drawerSectionSupport => _('drawerSectionSupport');
  String get drawerSectionRegisterOps => _('drawerSectionRegisterOps');
  String get drawerSectionAdvanced => _('drawerSectionAdvanced');
  String get bundleManagement => _('bundleManagement');
  String get closeShift => _('closeShift');
  String get printer => _('printer');
  String get printerSubtitle => _('printerSubtitle');
  String get clearLocalSales => _('clearLocalSales');
  String get clearLocalSalesSubtitle => _('clearLocalSalesSubtitle');
  String get resetAndSync => _('resetAndSync');
  String get resetAndSyncSubtitle => _('resetAndSyncSubtitle');
  String get checkUpdate => _('checkUpdate');
  String get checkUpdateSubtitle => _('checkUpdateSubtitle');
  String get thisDevice => _('thisDevice');
  String get inCloud => _('inCloud');

  // Inventory & History
  String get inventory => _('inventory');
  String get inventoryReconciliation => _('inventoryReconciliation');
  String get inventoryReconciliationSubtitle =>
      _('inventoryReconciliationSubtitle');
  String get stockCountModeLabel => _('stockCountModeLabel');
  String get stockCountModeQuantity => _('stockCountModeQuantity');
  String get stockCountModeQualitative => _('stockCountModeQualitative');
  String get qualitativeLevelAlto => _('qualitativeLevelAlto');
  String get qualitativeLevelMedio => _('qualitativeLevelMedio');
  String get qualitativeLevelBajo => _('qualitativeLevelBajo');
  String get qualitativeLevelResurtir => _('qualitativeLevelResurtir');
  String get qualitativeLevelCritico => _('qualitativeLevelCritico');
  String get qualitativeUnitOption => _('qualitativeUnitOption');
  String reconcileCurrentStock(String qty, String unit) =>
      _('reconcileCurrentStock')
          .replaceAll('{qty}', qty)
          .replaceAll('{unit}', unit);
  String reconcileCurrentLevel(String level) => _('reconcileCurrentLevel')
      .replaceAll('{level}', level);
  String get reconcileCountedQuantity => _('reconcileCountedQuantity');
  String get reconcileUnitLabel => _('reconcileUnitLabel');
  String get reconcileModeQuantityHint => _('reconcileModeQuantityHint');
  String get reconcileModeQualitativeHint =>
      _('reconcileModeQualitativeHint');
  String get reconcileSelectLevel => _('reconcileSelectLevel');
  String get reconcileSkip => _('reconcileSkip');
  String get reconcileSaveAndContinue => _('reconcileSaveAndContinue');
  String get reconcileDone => _('reconcileDone');
  String get reconcileEmpty => _('reconcileEmpty');
  String get reconcileSaved => _('reconcileSaved');
  String get reconcileCloudSyncFailed => _('reconcileCloudSyncFailed');
  String reconcileGroupLabel(String name) =>
      _('reconcileGroupLabel').replaceAll('{name}', name);
  String reconcileGroupsCounter(int current, int total) =>
      _('reconcileGroupsCounter')
          .replaceAll('{current}', '$current')
          .replaceAll('{total}', '$total');
  String reconcileInGroupCounter(int current, int total) =>
      _('reconcileInGroupCounter')
          .replaceAll('{current}', '$current')
          .replaceAll('{total}', '$total');
  String reconcileOverallCounter(int current, int total) =>
      _('reconcileOverallCounter')
          .replaceAll('{current}', '$current')
          .replaceAll('{total}', '$total');
  String get reconcileRestart => _('reconcileRestart');
  String get reconcileRestartConfirmTitle => _('reconcileRestartConfirmTitle');
  String get reconcileRestartConfirmBody => _('reconcileRestartConfirmBody');
  String get reconcilePreviousGroup => _('reconcilePreviousGroup');
  String get reconcileNextGroup => _('reconcileNextGroup');
  String get reconcileSelectGroup => _('reconcileSelectGroup');
  String get reconcileSearchHint => _('reconcileSearchHint');
  String get reconcileSearchNoResults => _('reconcileSearchNoResults');
  String get salesHistory => _('salesHistory');
  String get cancelMovement => _('cancelMovement');
  String get cancelMovementConfirmBody => _('cancelMovementConfirmBody');
  String get cancelSale => _('cancelSale');
  String get cancelSaleConfirmTitle => _('cancelSaleConfirmTitle');
  String get cancelSaleConfirmBody => _('cancelSaleConfirmBody');
  String get saleCancelled => _('saleCancelled');
  String get pendingCashierApprovalsTitle => _('pendingCashierApprovalsTitle');
  String get pendingCashierApprovalsSubtitle =>
      _('pendingCashierApprovalsSubtitle');
  String get pendingApprovalKindMovement => _('pendingApprovalKindMovement');
  String get pendingApprovalKindSaleCancel => _('pendingApprovalKindSaleCancel');
  String get pendingApprovalKindShiftClose => _('pendingApprovalKindShiftClose');
  String get pendingApprovalApprove => _('pendingApprovalApprove');
  String get pendingApprovalReject => _('pendingApprovalReject');
  String get pendingApprovalEmpty => _('pendingApprovalEmpty');
  String get pendingApprovalQueued => _('pendingApprovalQueued');
  String get pendingApprovalDuplicateShiftClose =>
      _('pendingApprovalDuplicateShiftClose');
  String get pendingApprovalRejectedSnack => _('pendingApprovalRejectedSnack');
  String get pendingApprovalShiftIdLabel => _('pendingApprovalShiftIdLabel');
  String get pendingApprovalExpectedCashLabel =>
      _('pendingApprovalExpectedCashLabel');
  String get pendingApprovalCashDifferenceLabel =>
      _('pendingApprovalCashDifferenceLabel');
  String pendingApprovalDeviceLine(String deviceId) =>
      _('pendingApprovalDeviceLine').replaceAll('{id}', deviceId);
  String pendingApprovalsDrawerSubtitle(int count) =>
      _('pendingApprovalsDrawerSubtitle')
          .replaceAll('{count}', '$count');
  String get salesHistoryAllDays => _('salesHistoryAllDays');
  String get salesHistoryPickDay => _('salesHistoryPickDay');
  String salesHistorySalesOnDate(String formattedDate) =>
      _('salesHistorySalesOnDate').replaceAll('{date}', formattedDate);

  String get platformOrdersTitle => _('platformOrdersTitle');
  String get platformOrdersSubtitle => _('platformOrdersSubtitle');
  String get platformOrdersUberEatsSection => _('platformOrdersUberEatsSection');
  String get platformOrdersByDayHint => _('platformOrdersByDayHint');
  String get platformOrdersRequiresCloud => _('platformOrdersRequiresCloud');
  String get platformOrdersLoadError => _('platformOrdersLoadError');
  String get platformOrdersEmptyUberEats => _('platformOrdersEmptyUberEats');
  String get platformOrdersEmptyHint => _('platformOrdersEmptyHint');
  String get platformOrdersNoSummary => _('platformOrdersNoSummary');
  String platformOrdersDayTotal(int count) =>
      _('platformOrdersDayTotal').replaceAll('{count}', '$count');

  // Reports
  String get reports => _('reports');
  String get reportsSubtitle => _('reportsSubtitle');
  String get temperatureHistory => _('temperatureHistory');
  String get temperatureHistorySubtitle => _('temperatureHistorySubtitle');
  String get temperatureRange24h => _('temperatureRange24h');
  String get temperatureRange7d => _('temperatureRange7d');
  String get temperatureRange30d => _('temperatureRange30d');
  String get temperatureSensorFilter => _('temperatureSensorFilter');
  String get temperatureFreezerFilter => _('temperatureFreezerFilter');
  String get temperatureFreezerAll => _('temperatureFreezerAll');
  String get temperatureFreezer1 => _('temperatureFreezer1');
  String get temperatureFreezer2 => _('temperatureFreezer2');
  String get temperatureSensorAll => _('temperatureSensorAll');
  String get temperatureUnknownSensor => _('temperatureUnknownSensor');
  String get temperatureSensorFreezer1Right => _('temperatureSensorFreezer1Right');
  String get temperatureSensorFreezer1Left => _('temperatureSensorFreezer1Left');
  String get temperatureSensorFreezer2Left => _('temperatureSensorFreezer2Left');
  String get temperatureNoData => _('temperatureNoData');
  String get temperatureCloudRequired => _('temperatureCloudRequired');
  String get temperatureStats => _('temperatureStats');
  String get temperaturePoints => _('temperaturePoints');
  String get temperatureFromTo => _('temperatureFromTo');
  String get temperatureMinMax => _('temperatureMinMax');
  String temperatureLastReading(String value, String at) =>
      _('temperatureLastReading')
          .replaceAll('{value}', value)
          .replaceAll('{at}', at);
  String get salesReports => _('salesReports');
  String get inventoryReports => _('inventoryReports');
  String get rayosXReport => _('rayosXReport');
  String get rayosXSubtitle => _('rayosXSubtitle');
  String get closuresOfDay => _('closuresOfDay');
  String get noClosuresThatDay => _('noClosuresThatDay');
  String get cutLabel => _('cutLabel');
  String get openingTime => _('openingTime');
  String get closingTime => _('closingTime');
  String get startingFund => _('startingFund');
  String get expectedInDrawer => _('expectedInDrawer');
  String get declaredCash => _('declaredCash');
  String get difference => _('difference');
  String get movements => _('movements');
  String get movementsCajaNetLabel => _('movementsCajaNetLabel');
  String get movementsSubtitle => _('movementsSubtitle');
  String get movementLinkShift => _('movementLinkShift');
  String get movementShiftNone => _('movementShiftNone');
  String movementShiftLabel(int shiftId) =>
      _('movementShiftLabel').replaceAll('{id}', '$shiftId');
  String get entry => _('entry');
  String get exit => _('exit');
  String get addMovement => _('addMovement');
  String get staffTasksTitle => _('staffTasksTitle');
  String get staffTasksAdminTitle => _('staffTasksAdminTitle');
  String get staffTasksMyTitle => _('staffTasksMyTitle');
  String get staffTasksSubtitle => _('staffTasksSubtitle');
  String get staffTaskNew => _('staffTaskNew');
  String get staffTaskEdit => _('staffTaskEdit');
  String get staffTaskTitleLabel => _('staffTaskTitleLabel');
  String get staffTaskDescriptionLabel => _('staffTaskDescriptionLabel');
  String get staffTaskScheduledAt => _('staffTaskScheduledAt');
  String get staffTaskNotifyAt => _('staffTaskNotifyAt');
  String get staffTaskNotifyNow => _('staffTaskNotifyNow');
  String get staffTaskCancel => _('staffTaskCancel');
  String get staffTaskCancelled => _('staffTaskCancelled');
  String get staffTaskMarkDone => _('staffTaskMarkDone');
  String get staffTaskMarkSkipped => _('staffTaskMarkSkipped');
  String get staffTaskComment => _('staffTaskComment');
  String get staffTaskCommentOptional => _('staffTaskCommentOptional');
  String get staffTaskStatusPending => _('staffTaskStatusPending');
  String get staffTaskStatusDone => _('staffTaskStatusDone');
  String get staffTaskStatusSkipped => _('staffTaskStatusSkipped');
  String get staffTaskDue => _('staffTaskDue');
  String get staffTaskResponses => _('staffTaskResponses');
  String get staffTaskNoTasks => _('staffTaskNoTasks');
  String get staffTaskCloudRequired => _('staffTaskCloudRequired');
  String get staffTaskSaved => _('staffTaskSaved');
  String get staffTaskSendDueReminders => _('staffTaskSendDueReminders');
  String staffTaskRemindersResult(int tasks, int push) =>
      _('staffTaskRemindersResult')
          .replaceAll('{tasks}', '$tasks')
          .replaceAll('{push}', '$push');
  String staffTaskDueAlert(int count) =>
      _('staffTaskDueAlert').replaceAll('{n}', '$count');
  String get staffTaskStatusInProgress => _('staffTaskStatusInProgress');
  String get staffTaskStatusScheduled => _('staffTaskStatusScheduled');
  String get staffTaskMarkInProgress => _('staffTaskMarkInProgress');
  String get staffTaskMarkOmitted => _('staffTaskMarkOmitted');
  String get staffTaskCommentRequired => _('staffTaskCommentRequired');
  String get staffTaskInvasiveTitle => _('staffTaskInvasiveTitle');
  String staffTaskInvasiveSubtitle(int count) =>
      _('staffTaskInvasiveSubtitle').replaceAll('{n}', '$count');
  String staffTaskPendingAlertTooltip(int count) =>
      _('staffTaskPendingAlertTooltip').replaceAll('{n}', '$count');
  String get voiceMicTooltip => _('voiceMicTooltip');
  String get voiceListening => _('voiceListening');
  String get voiceListeningHint => _('voiceListeningHint');
  String get voiceContinue => _('voiceContinue');
  String get voiceConfirmTitle => _('voiceConfirmTitle');
  String get voiceConfirmIncomplete => _('voiceConfirmIncomplete');
  String get voiceAmountLabel => _('voiceAmountLabel');
  String get voiceRegister => _('voiceRegister');
  String get voiceInvalidAmount => _('voiceInvalidAmount');
  String get voiceMissingReason => _('voiceMissingReason');
  String get voiceCommandNotUnderstood => _('voiceCommandNotUnderstood');
  String get voiceMicPermissionDenied => _('voiceMicPermissionDenied');
  String get voiceSttUnavailable => _('voiceSttUnavailable');
  String get voiceTextFallbackTitle => _('voiceTextFallbackTitle');
  String get voiceTextFallbackHint => _('voiceTextFallbackHint');
  String get staffTaskInvasiveDismiss => _('staffTaskInvasiveDismiss');
  String get staffTaskManageResponses => _('staffTaskManageResponses');
  String get staffTaskNoResponsesYet => _('staffTaskNoResponsesYet');
  String get staffTaskAdminChangeStatus => _('staffTaskAdminChangeStatus');
  String get staffTaskAdminStatusUpdated => _('staffTaskAdminStatusUpdated');
  String get staffTaskEmployee => _('staffTaskEmployee');
  String get quickSalesSummaryTitle => _('quickSalesSummaryTitle');
  String get quickSalesByShift => _('quickSalesByShift');
  String get quickCategoryDistribution => _('quickCategoryDistribution');
  String get quickTopProductsToday => _('quickTopProductsToday');
  String get quickTopProducts7d => _('quickTopProducts7d');
  String get quickTopProducts30d => _('quickTopProducts30d');
  String get quickNoData => _('quickNoData');
  String get concept => _('concept');
  String get accountCash => _('accountCash');
  String get accountBank => _('accountBank');
  String get period => _('period');
  String get periodToday => _('periodToday');
  String get periodYesterday => _('periodYesterday');
  String get periodThisWeek => _('periodThisWeek');
  String get periodLastWeek => _('periodLastWeek');
  String get periodThisMonth => _('periodThisMonth');
  String get periodLastMonth => _('periodLastMonth');
  String get startDate => _('startDate');
  String get endDate => _('endDate');
  String get totalSales => _('totalSales');
  String get numberOfSales => _('numberOfSales');
  String get salesByPaymentMethod => _('salesByPaymentMethod');
  String get topProductsByRevenue => _('topProductsByRevenue');
  String get product => _('product');
  String get quantitySold => _('quantitySold');
  String get revenue => _('revenue');
  String get currentStock => _('currentStock');
  String get reorderPoint => _('reorderPoint');
  String get inventoryValue => _('inventoryValue');
  String get lowStockAlert => _('lowStockAlert');
  String get recentMovements => _('recentMovements');
  String get reason => _('reason');
  String get changeAmount => _('changeAmount');
  String get reportSale => _('reportSale');
  String get reportPurchase => _('reportPurchase');
  String get reportWaste => _('reportWaste');
  String get reportReconciliation => _('reportReconciliation');

  // Descuentos
  String get discounts => _('discounts');
  String get discountCode => _('discountCode');
  String get discountByProduct => _('discountByProduct');
  String get percentageHint => _('percentageHint');
  String get applyToProductsContaining => _('applyToProductsContaining');
  String get labelOptional => _('labelOptional');
  String get applyCode => _('applyCode');
  String get applyProductDiscount => _('applyProductDiscount');
  String get codeApplied => _('codeApplied');
  String get invalidCode => _('invalidCode');
  String get discountAppliedProduct => _('discountAppliedProduct');
  String get discountCatalogTitle => _('discountCatalogTitle');
  String get discountPickFromList => _('discountPickFromList');
  String get discountDisplayNameHint => _('discountDisplayNameHint');
  String get discountCatalogEmpty => _('discountCatalogEmpty');
  String discountCatalogAppliedToast(String name) =>
      _('discountCatalogAppliedToast').replaceAll('{name}', name);
  String get discountInactiveLabel => _('discountInactiveLabel');
  String get discountShowAtRegister => _('discountShowAtRegister');
  String get discountSave => _('discountSave');
  String get discountDeleteConfirmTitle => _('discountDeleteConfirmTitle');
  String get discountDeleteAction => _('discountDeleteAction');
  String get discountCatalogSaved => _('discountCatalogSaved');
  String get discountManagement => _('discountManagement');
  String get noDiscountsHint => _('noDiscountsHint');
  String get newDiscount => _('newDiscount');
  String get editDiscount => _('editDiscount');
  String get discountType => _('discountType');
  String get discountTypeEmployee => _('discountTypeEmployee');
  String get discountTypePercentage => _('discountTypePercentage');
  String get discountTypeEmployeeHint => _('discountTypeEmployeeHint');
  String get discountTypePercentageHint => _('discountTypePercentageHint');
  String get discountCodeRequired => _('discountCodeRequired');
  String get invalidPercentage => _('invalidPercentage');
  String get discountSaved => _('discountSaved');
  String get deleteDiscount => _('deleteDiscount');
  String get deleteDiscountConfirm => _('deleteDiscountConfirm');
  String get importEmployeePrices => _('importEmployeePrices');
  String get importEmployeePricesConfirm => _('importEmployeePricesConfirm');
  String get importAction => _('importAction');
  String importEmployeePricesDone(int count) =>
      _('importEmployeePricesDone').replaceAll('{n}', '$count');
  String get employeePrice => _('employeePrice');
  String get employeePriceOptional => _('employeePriceOptional');
  String get descriptionOptional => _('descriptionOptional');
  String get active => _('active');
  String get inactive => _('inactive');
  String get delete => _('delete');
  String get save => _('save');
  String get employeeDiscountLabel => _('employeeDiscountLabel');

  // Reset / Vaciar
  String get clearLocalSalesConfirmTitle => _('clearLocalSalesConfirmTitle');
  String get clearLocalSalesConfirmBody => _('clearLocalSalesConfirmBody');
  String get clear => _('clear');
  String get clearLocalSalesDone => _('clearLocalSalesDone');
  String get resetConfirmTitle => _('resetConfirmTitle');
  String get resetConfirmBody => _('resetConfirmBody');
  String get resetAndSyncButton => _('resetAndSyncButton');
  String get resettingAndSyncing => _('resettingAndSyncing');
  String get resetSuccess => _('resetSuccess');
  String get resetError => _('resetError');

  // Language dialog
  String get selectLanguage => _('selectLanguage');
  String get spanish => _('spanish');
  String get english => _('english');

  // Close shift / corte
  String get expectedCashInDrawer => _('expectedCashInDrawer');
  String get enterCountedAmounts => _('enterCountedAmounts');
  String get totalCashInDrawer => _('totalCashInDrawer');
  String get totalCashInDrawerHint => _('totalCashInDrawerHint');
  String get salesDebit => _('salesDebit');
  String get salesCredit => _('salesCredit');
  String get salesTransfer => _('salesTransfer');
  String get submitCount => _('submitCount');
  String get next => _('next');
  String get closureSummary => _('closureSummary');
  String closeShiftTurnIdLine(int shiftId) =>
      _('closeShiftTurnIdLine').replaceAll('{id}', '$shiftId');
  String closeShiftTurnIdsLocalCloud(int localId, int cloudId) =>
      _('closeShiftTurnIdsLocalCloud')
          .replaceAll('{l}', '$localId')
          .replaceAll('{c}', '$cloudId');
  String get supabaseIdShort => _('supabaseIdShort');
  String get closeShiftTurnIdHint => _('closeShiftTurnIdHint');
  String get closeShiftCloudLoading => _('closeShiftCloudLoading');
  String get closeShiftCloudSectionTitle => _('closeShiftCloudSectionTitle');
  String get closeShiftCloudNoNetwork => _('closeShiftCloudNoNetwork');
  String closeShiftCloudQueryError(String msg) =>
      _('closeShiftCloudQueryError').replaceAll('{msg}', msg);
  String get closeShiftCloudRowMissing => _('closeShiftCloudRowMissing');
  String closeShiftCloudAlreadyClosed(String at) =>
      _('closeShiftCloudAlreadyClosed').replaceAll('{at}', at);
  String closeShiftCloudOpenMismatch(String localId, String openId) =>
      _('closeShiftCloudOpenMismatch')
          .replaceAll('{local}', localId)
          .replaceAll('{open}', openId);
  String get closeShiftCloudAligned => _('closeShiftCloudAligned');
  String get closeShiftCloudNoOpenForDevice => _('closeShiftCloudNoOpenForDevice');
  String get closeCut => _('closeCut');
  String get goBack => _('goBack');
  String get notesOptional => _('notesOptional');
  String get validAmount => _('validAmount');
  String get cardDeclaredRequired => _('cardDeclaredRequired');
  String get cardMismatchTitle => _('cardMismatchTitle');
  String get cardMismatchMessage => _('cardMismatchMessage');
  String get cardSalesSystem => _('cardSalesSystem');
  String get cardDeclared => _('cardDeclared');
  String get cardTerminalHint => _('cardTerminalHint');
  String get closureCorrect => _('closureCorrect');
  String get closureIncorrectCardOnly => _('closureIncorrectCardOnly');
  String get closureIncorrectCashAndCard => _('closureIncorrectCashAndCard');
  String get differenceInCash => _('differenceInCash');
  String get closeShiftNoOpen => _('closeShiftNoOpen');
  String get closeShiftNoOpenHint => _('closeShiftNoOpenHint');
  String get openShiftButton => _('openShiftButton');
  String get openShiftStartingFundTitle => _('openShiftStartingFundTitle');
  String get openShiftStartingFundBody => _('openShiftStartingFundBody');
  String get posRegisterTitle => _('posRegisterTitle');
  String get posRegisterSubtitle => _('posRegisterSubtitle');
  String get posRegisterChooseHint => _('posRegisterChooseHint');
  String get posRegisterSaved => _('posRegisterSaved');
  String get continueOpenShiftButton => _('continueOpenShiftButton');
  String get continueOpenShiftTitle => _('continueOpenShiftTitle');
  String get continueOpenShiftEmpty => _('continueOpenShiftEmpty');
  String get continueOpenShiftLoading => _('continueOpenShiftLoading');
  String closeShiftCloudCancelledApplied(int count) =>
      _('closeShiftCloudCancelledApplied').replaceAll('{count}', '$count');
  String continueOpenShiftLine(String label, String shiftId, String started) =>
      _('continueOpenShiftLine')
          .replaceAll('{label}', label)
          .replaceAll('{shift}', shiftId)
          .replaceAll('{started}', started);
  String get posRequiresOpenShiftBanner => _('posRequiresOpenShiftBanner');
  String get posRequiresOpenShiftAction => _('posRequiresOpenShiftAction');
  String get posTopSellersStrip => _('posTopSellersStrip');
  String get posTopSellersEmpty => _('posTopSellersEmpty');

  String get retry => _('retry');
  String get storesRegistersAdminTitle => _('storesRegistersAdminTitle');
  String get storesAdminAddStoreTitle => _('storesAdminAddStoreTitle');
  String get storesAdminStoreNameLabel => _('storesAdminStoreNameLabel');
  String get storesAdminEmpty => _('storesAdminEmpty');
  String storesAdminStoreIdLine(int id) =>
      _('storesAdminStoreIdLine').replaceAll('{id}', '$id');
  String get storesAdminSaved => _('storesAdminSaved');
  String get storesAdminEditStoreTitle => _('storesAdminEditStoreTitle');
  String get storesAdminRegistersSubtitle => _('storesAdminRegistersSubtitle');
  String get storesAdminAddRegisterTitle => _('storesAdminAddRegisterTitle');
  String get storesAdminRegisterLabelHint => _('storesAdminRegisterLabelHint');
  String get storesAdminEditRegisterTitle => _('storesAdminEditRegisterTitle');
  String get storesAdminDisplayOrderLabel => _('storesAdminDisplayOrderLabel');
  String get storesAdminNoRegisters => _('storesAdminNoRegisters');
  String storesAdminRegisterIdLine(int id) =>
      _('storesAdminRegisterIdLine').replaceAll('{id}', '$id');
  String get storesAdminOrderLabel => _('storesAdminOrderLabel');
  String get storesAdminActive => _('storesAdminActive');
  String get storesAdminInactive => _('storesAdminInactive');
  String get storesAdminDeactivate => _('storesAdminDeactivate');
  String get storesAdminActivate => _('storesAdminActivate');

  String get adminLinkOpenShiftTitle => _('adminLinkOpenShiftTitle');
  String get adminLinkOpenShiftSubtitle => _('adminLinkOpenShiftSubtitle');
  String get adminLinkOpenShiftLoading => _('adminLinkOpenShiftLoading');
  String get adminLinkOpenShiftEmpty => _('adminLinkOpenShiftEmpty');
  String get adminLinkOpenShiftRequiresLocalDb => _('adminLinkOpenShiftRequiresLocalDb');
  String get adminLinkOpenShiftConfirmTitle => _('adminLinkOpenShiftConfirmTitle');
  String adminLinkOpenShiftConfirmBody(int shiftId, String store, String register) =>
      _('adminLinkOpenShiftConfirmBody')
          .replaceAll('{id}', '$shiftId')
          .replaceAll('{store}', store)
          .replaceAll('{register}', register);
  String get adminLinkOpenShiftUnlinkNote => _('adminLinkOpenShiftUnlinkNote');
  String get adminLinkOpenShiftLinking => _('adminLinkOpenShiftLinking');
  String get adminLinkOpenShiftLinkedOk => _('adminLinkOpenShiftLinkedOk');
  String adminLinkOpenShiftLine(String store, String register, String shiftId, String started) =>
      _('adminLinkOpenShiftLine')
          .replaceAll('{store}', store)
          .replaceAll('{register}', register)
          .replaceAll('{shift}', shiftId)
          .replaceAll('{started}', started);
  String adminLinkOpenShiftDeviceLine(String device) =>
      _('adminLinkOpenShiftDeviceLine').replaceAll('{device}', device);

  static const Map<String, String> _es = {
    'appTitle': 'ICE POS',
    'menu': 'Menú',
    'language': 'Idioma',
    'languageNameEs': 'Español',
    'languageNameEn': 'English',
    'cancel': 'Cancelar',
    'done': 'Listo',
    'close': 'Cerrar',
    'apply': 'Aplicar',
    'ok': 'Aceptar',
    'error': 'Error',
    'cloudActive': 'Nube activa',
    'cloudNotConfigured': 'Nube no configurada',
    'syncWithSupabase': 'Sincronización con Supabase',
    'syncEnvHint': 'Configura SUPABASE_URL y SUPABASE_ANON_KEY en .env',
    'setupSupabaseTitle': 'Conectar con la nube',
    'setupSupabaseSubtitle':
        'Introduce la URL del proyecto y la clave anónima (anon public) de Supabase. Se guardan en el dispositivo para conectar automáticamente al abrir la app.',
    'setupSupabaseUrlLabel': 'URL del proyecto (https://…supabase.co)',
    'setupSupabaseAnonKeyLabel': 'Clave anónima (anon key)',
    'setupSupabaseConnect': 'Conectar y sincronizar',
    'setupSupabaseSkip': 'Continuar sin nube',
    'setupSupabaseSchemaNote':
        'Las tablas y políticas deben existir en tu proyecto Supabase. En el repositorio, ejecuta los SQL de la carpeta supabase/migrations (SQL Editor o CLI). La app no puede crear el esquema solo con la clave anon.',
    'setupSupabaseInvalidUrl': 'La URL debe empezar con https:// y ser un host válido.',
    'setupSupabaseConnecting': 'Conectando…',
    'setupSupabaseError': 'No se pudo conectar. Revisa URL, clave y red.',
    'testConnection': 'Probar conexión',
    'connectionOk': 'Conexión con la nube OK',
    'sync': 'Sincronizar',
    'syncFromCloud': 'Sincronizar desde la nube',
    'sendToCloud': 'Enviar datos a la nube',
    'sendToCloudSubtitle': 'La nube será la fuente de verdad',
    'syncingFromCloud': 'Sincronizando desde la nube...',
    'syncSuccess': 'Sincronización correcta. Datos locales actualizados desde la nube.',
    'syncError': 'Error al sincronizar',
    'syncStepStarting': 'Iniciando sincronización…',
    'syncStepDownloadingCategories': 'Descargando categorías…',
    'syncStepDownloadingProducts': 'Descargando productos e insumos…',
    'syncStepDownloadingRecipes': 'Descargando recetas y modificadores…',
    'syncStepDownloadingBundles': 'Descargando bundles y descuentos…',
    'syncStepSavingLocal': 'Preparando base local…',
    'syncStepSavingCategories': 'Guardando categorías…',
    'syncStepSavingProducts': 'Guardando productos e insumos…',
    'syncStepSavingRecipes': 'Guardando recetas y modificadores…',
    'syncStepSavingBundles': 'Guardando bundles y descuentos…',
    'syncStepFinishing': 'Finalizando…',
    'syncStepProgress': 'Paso {step}',
    'catalogMenuCacheLastSync': 'Menú en caché (nube): {when}',
    'catalogMenuCacheNever': 'Menú en caché: aún no sincronizado desde la nube',
    'offlineBanner':
        'Sin conexión: puedes cobrar y usar caja; el menú y administración solo con internet.',
    'offlineRequiresInternet':
        'Conéctate a internet para sincronizar o editar el menú.',
    'sendingToCloud': 'Enviando datos a la nube...',
    'dataSentToCloud': 'Datos enviados a la nube',
    'loadMenuFromJson': 'Cargar menú desde JSON',
    'loadMenuFromJsonSubtitle': 'Solo cuando la nube está vacía. Si la nube tiene datos, se sincronizan automáticamente.',
    'importRecipesFromJson': 'Importar recetas (recetas_formato.json)',
    'importRecipesFromJsonSubtitle':
        'Actualiza la tabla local de recetas y genera un CSV de reporte. Los modificadores del JSON no se importan aquí.',
    'importRecipesConfirmTitle': '¿Importar recetas?',
    'importRecipesConfirmBody':
        'Para cada producto del JSON con ingredientes: se borran las recetas locales de ese producto y se insertan las del archivo. Productos sin ingredientes en el JSON no se tocan. Se guardará un CSV con el detalle.',
    'importRecipesPushCloudTitle': '¿Subir recetas a la nube?',
    'importRecipesPushCloudBody':
        'Se enviará cada producto actualizado a Supabase (recetas y datos del producto). Requiere conexión.',
    'importRecipesPushCloudLocal': 'Solo local',
    'importRecipesPushCloudYes': 'Sí, subir a la nube',
    'importingRecipes': 'Importando recetas...',
    'importRecipesDone': 'Importación terminada.',
    'importRecipesReportPath': 'Reporte CSV:',
    'importRecipesReportClipboard': 'Reporte copiado al portapapeles.',
    'loadingMenuFromJson': 'Cargando menú desde JSON...',
    'loadingMenuAndSending': 'Cargando menú y enviando a la nube...',
    'menuReloaded': 'Menú recargado (Bolis, Paletas, Nieves, Malteadas)',
    'reloadMenuConfirmTitle': 'Recargar menú',
    'reloadMenuConfirmBody': 'Se borrarán categorías y productos que pertenezcan a una categoría y se cargará desde menu_reyes_nieves.json. Los productos sin categoría se conservan.',
    'reload': 'Recargar',
    'loadJsonNotAllowedTitle': 'Cargar desde JSON no permitido',
    'loadJsonNotAllowedBody': 'La nube ya tiene datos. Para que todos los dispositivos tengan los mismos IDs, solo se puede cargar desde JSON cuando la nube está vacía. En este dispositivo el menú se actualiza automáticamente desde la nube.',
    'later': 'Más tarde',
    'yesLoadAndSend': 'Sí, cargar y enviar',
    'updateAvailable': 'Actualización disponible',
    'download': 'Descargar',
    'operationLogTitle': 'Registro de operaciones',
    'operationLogSubtitle':
        'Nivel critical = fallo de escritura en base local o nube. También: venta, sync al arranque, Flutter/async, Riverpod. Solo en este dispositivo.',
    'operationLogEmpty':
        'No hay entradas todavía. Si una venta falla o la nube no guarda la venta, aparecerá aquí.',
    'shiftCloseDiagnosticsTitle': 'Diagnóstico cierre de caja',
    'shiftCloseDiagnosticsMenuSubtitle': 'Eventos en la nube por dispositivo al cerrar turno.',
    'shiftCloseDiagnosticsSubtitle':
        'Eventos en la nube por dispositivo: descarga de movimientos al abrir corte, cierre local y envío a Supabase. Orden: más recientes primero.',
    'shiftCloseDiagnosticsEmpty':
        'Aún no hay eventos. Aparecen al abrir la pantalla de cierre de caja (pull de movimientos) o al confirmar un corte en un POS con nube activa.',
    'shiftCloseDiagnosticsDisabled': 'La nube no está configurada; no hay eventos que mostrar.',
    'cloudPosDiagnosticsTitle': 'Nube · caja y dispositivos',
    'shiftCloseEventsTab': 'Eventos',
    'devicesAndClosuresTab': 'Dispositivos',
    'registerDeviceToCloudTitle': 'Registrar en la nube',
    'registerDeviceToCloudSubtitle':
        'Envía este equipo a la lista de terminales y actualiza el turno abierto con su ID (cajero y admin).',
    'registerDeviceToCloudOk': 'Dispositivo y turno actualizados en la nube.',
    'cloudDevicesEmpty':
        'Ningún dispositivo registrado todavía. Use “Registrar en la nube” en cada caja con internet.',
    'cloudDeviceLastSeen': 'Último registro',
    'cloudDeviceOpenShift': 'Turno abierto (nube)',
    'cloudDeviceNoOpenShift': 'No hay turno abierto en la nube para este dispositivo.',
    'cloudRemoteCloseShift': 'Cerrar turno remoto',
    'cloudRemoteCloseShiftHint':
        'Cierra solo en Supabase: la caja física puede seguir con turno local hasta que sincronice o cierre allí. El efectivo esperado se calcula con ventas en nube de este dispositivo en el rango del turno y movimientos de caja del shift_id.',
    'cloudSalesByDevice': 'Ventas recientes (nube)',
    'cloudClosuresByDevice': 'Cortes registrados (nube)',
    'cloudShiftClosedRemoteOk': 'Turno cerrado en la nube.',
    'cloudNoSalesForDevice': 'Sin ventas en nube para este dispositivo.',
    'cloudNoClosuresForDevice': 'Sin cortes en nube para este dispositivo.',
    'storeLabel': 'Tienda',
    'exportOperationLog': 'Exportar y compartir (.txt)',
    'clearOperationLogConfirmTitle': '¿Borrar el registro?',
    'clearOperationLogConfirmBody':
        'Se eliminarán todas las entradas de diagnóstico de este dispositivo.',
    'versionBuild': 'Versión',
    'downloadHint': 'Pulsa "Descargar" para abrir el enlace e instalar la nueva versión.',
    'downloadLinkCopied': 'Enlace copiado. Pégalo en el navegador para descargar.',
    'alreadyLatestVersion': 'Ya tienes la última versión.',
    'remoteUpdateRequestedTitle': 'Actualización solicitada',
    'remoteUpdateRequestedBodyDefault':
        'El administrador pide que esta caja compruebe e instale la última versión cuando pueda.',
    'remoteUpdateCheckNow': 'Comprobar actualización',
    'remoteUpdateAckLater': 'Más tarde',
    'cloudRequestAppUpdate': 'Solicitar actualización en la caja',
    'cloudRequestAppUpdateSubtitle':
        'La próxima vez que abran la app o vuelvan a esta pantalla verán un aviso (requiere internet en la caja).',
    'cloudClearUpdateRequest': 'Quitar solicitud',
    'cloudUpdateRequestSent': 'Solicitud registrada para este dispositivo.',
    'cloudUpdateRequestCleared': 'Solicitud quitada.',
    'cloudUpdateRequestMessageHint': 'Mensaje opcional para la caja',
    'cloudUpdatePendingBadge': 'Actualización pendiente',
    'login': 'Iniciar sesión',
    'username': 'Usuario',
    'emailOrUsername': 'Usuario o correo',
    'password': 'Contraseña',
    'signIn': 'Entrar',
    'invalidCredentials': 'Usuario o contraseña incorrectos',
    'logout': 'Cerrar sesión',
    'logoutHint': 'Salir y volver a la pantalla de login',
    'adminAccess': 'Acceso administrador',
    'adminAccessHint': 'Solo administradores pueden ver categorías, productos, insumos, corte y sincronización.',
    'enterAdminPin': 'Introduce PIN de administrador',
    'setAdminPin': 'Establecer PIN (4 dígitos)',
    'invalidPin': 'PIN incorrecto',
    'lockAsEmployee': 'Bloquear como empleado',
    'lockAsEmployeeHint': 'Solo Punto de venta e historial del día',
    'salesToday': 'Ventas del día',
    'employeeMode': 'Modo empleado',
    'pointOfSale': 'Punto de venta',
    'quickSearchHint': 'Buscar por nombre…',
    'searchNoResults': 'Sin resultados',
    'cart': 'Carrito',
    'cartEmpty': 'Carrito vacío',
    'checkout': 'Cobrar',
    'total': 'Total',
    'bundles': 'Bundles',
    'subtotalOther': 'Subtotal (otros)',
    'discount': 'Descuento',
    'removeDiscount': 'Quitar descuento',
    'applyDiscount': 'Aplicar descuento',
    'scanDiscount': 'Escanear descuento',
    'park': 'Aparcar',
    'processingSale': 'Procesando venta...',
    'saleComplete': 'Venta completada con éxito',
    'ticketSent': 'Ticket enviado a impresora',
    'printError': 'Error al imprimir',
    'printingTicket': 'Imprimiendo ticket...',
    'reprintTicket': 'Reimprimir ticket',
    'saleCompletePrintError': 'Venta completada. No se pudo imprimir el ticket',
    'amountReceived': 'Cantidad recibida',
    'change': 'Cambio',
    'exactAmount': 'Monto exacto',
    'confirmSale': 'Confirmar venta',
    'cash': 'Efectivo',
    'card': 'Tarjeta',
    'transfer': 'Transferencia',
    'debit': 'Débito',
    'credit': 'Crédito',
    'verifyTransfer': 'Verifica la transferencia en tu app bancaria antes de confirmar.',
    'singlePayment': 'Un método',
    'splitPayment': 'Dividido',
    'addPaymentMethod': 'Agregar pago',
    'splitPaymentRemaining': 'Falta por cubrir',
    'splitPaymentComplete': 'Total cubierto',
    'splitPaymentOverpaid': 'Sobra',
    'amount': 'Monto',
    'payment': 'Pago',
    'remove': 'Quitar',
    'errorLoading': 'Error al cargar',
    'discountPercent': 'Descuento',
    'productDiscountLabel': '% en',
    'supplyManagement': 'Insumos',
    'productManagement': 'Productos',
    'categoryManagement': 'Categorías',
    'categoryManagementSubtitle': 'Crear y editar categorías; asignar productos',
    'webAdminHomeTitle': 'Panel',
    'webAdminHomeSubtitle':
        'Gestiona catálogo, inventario y ventas conectado a Supabase. Usa el menú lateral para más opciones.',
    'webQuickAccess': 'Accesos rápidos',
    'drawerSectionGeneral': 'General',
    'drawerSectionDeviceCloud': 'Dispositivo y nube',
    'drawerSectionCloudData': 'Nube y datos',
    'drawerSectionCatalog': 'Catálogo e inventario',
    'drawerSectionSalesReports': 'Ventas e informes',
    'drawerSectionOrganization': 'Organización',
    'drawerSectionSupport': 'Soporte y diagnóstico',
    'drawerSectionRegisterOps': 'Caja y equipo',
    'drawerSectionAdvanced': 'Avanzado',
    'bundleManagement': 'Bundles',
    'closeShift': 'Cierre de caja',
    'printer': 'Impresora',
    'printerSubtitle': 'Configurar impresora Bluetooth',
    'clearLocalSales': 'Vaciar ventas locales',
    'clearLocalSalesSubtitle': 'Borra el historial de ventas de este dispositivo. No afecta la nube.',
    'resetAndSync': 'Restablecer todo y cargar desde la nube',
    'resetAndSyncSubtitle': 'Borra todos los datos locales (menú, ventas, turnos) y vuelve a traer todo desde Supabase.',
    'checkUpdate': 'Comprobar actualización',
    'checkUpdateSubtitle': 'Ver si hay nueva versión de la app',
    'thisDevice': 'Este dispositivo',
    'inCloud': 'En la nube',
    'inventory': 'Inventario',
    'inventoryReconciliation': 'Conciliación de inventario',
    'inventoryReconciliationSubtitle':
        'Recorrer cada insumo y ajustar cantidad o nivel',
    'stockCountModeLabel': 'Forma de medir inventario',
    'stockCountModeQuantity': 'Cantidad (numérica)',
    'stockCountModeQualitative': 'Nivel (alto / medio / bajo / crítico)',
    'qualitativeLevelAlto': 'Alto',
    'qualitativeLevelMedio': 'Medio',
    'qualitativeLevelBajo': 'Bajo',
    'qualitativeLevelResurtir': 'Resurtir',
    'qualitativeLevelCritico': 'Crítico',
    'qualitativeUnitOption': 'Cualitativo (nivel)',
    'reconcileCurrentStock': 'Stock en sistema: {qty} {unit}',
    'reconcileCurrentLevel': 'Nivel en sistema: {level}',
    'reconcileCountedQuantity': 'Cantidad física contada',
    'reconcileUnitLabel': 'Unidad de medida',
    'reconcileModeQuantityHint':
        'Introduce la cantidad contada. Se registrará la diferencia respecto al sistema.',
    'reconcileModeQualitativeHint':
        'Elige el nivel observado. El sistema guarda un equivalente numérico para recetas.',
    'reconcileSelectLevel': 'Nivel observado',
    'reconcileSkip': 'Siguiente sin guardar',
    'reconcileSaveAndContinue': 'Guardar y continuar',
    'reconcileDone': 'Terminar',
    'reconcileEmpty': 'No hay insumos para conciliar.',
    'reconcileSaved': 'Inventario actualizado',
    'reconcileCloudSyncFailed':
        'Guardado en el dispositivo. No se pudo subir a la nube; al sincronizar puede volver el valor anterior. Detalle: ',
    'reconcileGroupLabel': 'Grupo: {name}',
    'reconcileGroupsCounter': 'Grupo {current} de {total}',
    'reconcileInGroupCounter': 'En este grupo: {current} / {total}',
    'reconcileOverallCounter': 'Total: {current} / {total}',
    'reconcileRestart': 'Volver a empezar',
    'reconcileRestartConfirmTitle': '¿Reiniciar conciliación?',
    'reconcileRestartConfirmBody':
        'Se borrará el progreso guardado en este dispositivo y volverás al primer insumo del primer grupo.',
    'reconcilePreviousGroup': 'Grupo anterior',
    'reconcileNextGroup': 'Siguiente grupo',
    'reconcileSelectGroup': 'Elegir grupo',
    'reconcileSearchHint': 'Buscar insumo en todos los grupos…',
    'reconcileSearchNoResults': 'Ningún insumo coincide con la búsqueda.',
    'salesHistory': 'Historial de ventas',
    'cancelSale': 'Cancelar venta',
    'cancelMovement': 'Cancelar movimiento',
    'cancelMovementConfirmBody': 'El movimiento dejará de contar en el corte de caja. Esta acción no se puede deshacer.',
    'cancelSaleConfirmTitle': 'Cancelar venta',
    'cancelSaleConfirmBody': 'Se borrará esta venta solo en este dispositivo. El inventario no se revierte (si fue una venta de prueba, ajusta el stock manualmente si hace falta).',
    'saleCancelled': 'Venta cancelada',
    'pendingCashierApprovalsTitle': 'Aprobaciones de cajero',
    'pendingCashierApprovalsSubtitle':
        'Movimientos, cancelaciones de venta y cierres con faltante de efectivo',
    'pendingApprovalKindMovement': 'Movimiento',
    'pendingApprovalKindSaleCancel': 'Cancelar venta',
    'pendingApprovalKindShiftClose': 'Cierre de caja',
    'pendingApprovalApprove': 'Aprobar',
    'pendingApprovalReject': 'Rechazar',
    'pendingApprovalEmpty': 'No hay solicitudes pendientes.',
    'pendingApprovalQueued':
        'Solicitud enviada. Un administrador debe aprobarla en este mismo dispositivo.',
    'pendingApprovalDuplicateShiftClose':
        'Ya hay un cierre de caja pendiente de aprobación para este turno.',
    'pendingApprovalRejectedSnack': 'Solicitud rechazada',
    'pendingApprovalShiftIdLabel': 'Turno local',
    'pendingApprovalExpectedCashLabel': 'Efectivo esperado en caja',
    'pendingApprovalCashDifferenceLabel': 'Diferencia (declarado − esperado)',
    'pendingApprovalDeviceLine': 'Dispositivo: {id}',
    'pendingApprovalsDrawerSubtitle': '{count} pendiente(s)',
    'salesHistoryAllDays': 'Todos',
    'salesHistoryPickDay': 'Elegir día',
    'salesHistorySalesOnDate': 'Ventas del {date}',
    'platformOrdersTitle': 'Pedidos por plataforma',
    'platformOrdersSubtitle': 'Uber Eats por día (desde la nube)',
    'platformOrdersUberEatsSection': 'Uber Eats',
    'platformOrdersByDayHint':
        'Pedidos cuya hora cae en el día elegido (hora del dispositivo). Los datos vienen de la tabla platform_orders en Supabase.',
    'platformOrdersRequiresCloud': 'Configura Supabase para ver pedidos de plataformas.',
    'platformOrdersLoadError': 'No se pudieron cargar los pedidos',
    'platformOrdersEmptyUberEats': 'No hay pedidos de Uber Eats este día.',
    'platformOrdersEmptyHint':
        'Cuando la integración escriba filas en platform_orders (store_id de la tienda, platform = uber_eats), aparecerán aquí.',
    'platformOrdersNoSummary': 'Sin detalle de líneas.',
    'platformOrdersDayTotal': '{count} pedidos · total del día',
    'reports': 'Reportes',
    'reportsSubtitle': 'Estadísticas de ventas e inventario',
    'temperatureHistory': 'Temperatura (congelador)',
    'temperatureHistorySubtitle':
        'Historial desde la nube (tabla temperature_readings). Requiere Supabase configurado.',
    'temperatureRange24h': '24 h',
    'temperatureRange7d': '7 días',
    'temperatureRange30d': '30 días',
    'temperatureSensorFilter': 'Sensor',
    'temperatureFreezerFilter': 'Congelador',
    'temperatureFreezerAll': 'Todos los congeladores',
    'temperatureFreezer1': 'Congelador 1 (izq. y der.)',
    'temperatureFreezer2': 'Congelador 2',
    'temperatureSensorAll': 'Todos los sensores',
    'temperatureUnknownSensor': 'Sin sensor',
    'temperatureSensorFreezer1Right': 'Congelador 1 — derecha',
    'temperatureSensorFreezer1Left': 'Congelador 1 — izquierda',
    'temperatureSensorFreezer2Left': 'Congelador 2 — izquierda',
    'temperatureNoData': 'No hay lecturas en este rango.',
    'temperatureCloudRequired':
        'Configura SUPABASE_URL y SUPABASE_ANON_KEY en .env para ver el historial de temperatura.',
    'temperatureStats': 'Resumen',
    'temperaturePoints': 'Lecturas',
    'temperatureFromTo': 'Desde — hasta',
    'temperatureMinMax': 'Mín — máx',
    'temperatureLastReading': 'Última lectura: {value} °C — {at}',
    'salesReports': 'Ventas',
    'inventoryReports': 'Inventario',
    'rayosXReport': 'Rayos X del día',
    'rayosXSubtitle': 'Resumen de ventas y cortes del día',
    'closuresOfDay': 'Cortes del día',
    'noClosuresThatDay': 'No hay cortes registrados este día',
    'cutLabel': 'Corte',
    'openingTime': 'Apertura',
    'closingTime': 'Cierre',
    'startingFund': 'Fondo inicial',
    'expectedInDrawer': 'Esperado en caja',
    'declaredCash': 'Declarado',
    'difference': 'Diferencia',
    'movements': 'Movimientos',
    'movementsCajaNetLabel': 'Movimientos (entradas - salidas)',
    'movementsSubtitle': 'Entradas y salidas de caja o banco (no son ventas)',
    'movementLinkShift': 'Turno (caja)',
    'movementShiftNone': 'Sin turno',
    'movementShiftLabel': 'Turno #{id}',
    'entry': 'Entrada',
    'exit': 'Salida',
    'addMovement': 'Nuevo movimiento',
    'staffTasksTitle': 'Tareas',
    'staffTasksAdminTitle': 'Tareas del personal',
    'staffTasksMyTitle': 'Mis tareas',
    'staffTasksSubtitle': 'Asigna y da seguimiento a tareas del equipo',
    'staffTaskNew': 'Nueva tarea',
    'staffTaskEdit': 'Editar tarea',
    'staffTaskTitleLabel': 'Título',
    'staffTaskDescriptionLabel': 'Descripción (opcional)',
    'staffTaskScheduledAt': 'Fecha y hora límite',
    'staffTaskNotifyAt': 'Recordatorio (opcional)',
    'staffTaskNotifyNow': 'Enviar recordatorio ahora',
    'staffTaskCancel': 'Cancelar tarea',
    'staffTaskCancelled': 'Cancelada',
    'staffTaskMarkDone': 'Completada',
    'staffTaskMarkSkipped': 'Omitida',
    'staffTaskComment': 'Comentario',
    'staffTaskCommentOptional': 'Comentario (opcional)',
    'staffTaskStatusPending': 'Pendiente',
    'staffTaskStatusDone': 'Hecha',
    'staffTaskStatusSkipped': 'Omitida',
    'staffTaskDue': 'Vence',
    'staffTaskResponses': 'Respuestas',
    'staffTaskNoTasks': 'No hay tareas',
    'staffTaskCloudRequired': 'Requiere conexión a la nube',
    'staffTaskSaved': 'Tarea guardada',
    'staffTaskSendDueReminders': 'Enviar recordatorios programados',
    'staffTaskRemindersResult': 'Recordatorios: {tasks} tarea(s), {push} push enviado(s)',
    'staffTaskDueAlert': 'Tienes {n} tarea(s) por completar.',
    'staffTaskStatusInProgress': 'En progreso',
    'staffTaskStatusScheduled': 'Programada',
    'staffTaskMarkInProgress': 'Iniciar',
    'staffTaskMarkOmitted': 'Omitir',
    'staffTaskCommentRequired': 'Motivo (obligatorio)',
    'staffTaskInvasiveTitle': 'Tareas pendientes',
    'staffTaskInvasiveSubtitle': 'Completa {n} actividad(es) antes de continuar',
    'staffTaskPendingAlertTooltip': '{n} tarea(s) pendiente(s). Toca para ver',
    'voiceMicTooltip': 'Movimiento por voz',
    'voiceListening': 'Escuchando…',
    'voiceListeningHint': 'Di por ejemplo: entrada 200 pesos por sueldo',
    'voiceContinue': 'Continuar',
    'voiceConfirmTitle': 'Confirmar movimiento',
    'voiceConfirmIncomplete': 'Completa los campos faltantes antes de registrar.',
    'voiceAmountLabel': 'Monto',
    'voiceRegister': 'Registrar',
    'voiceInvalidAmount': 'Monto inválido',
    'voiceMissingReason': 'Indica el concepto',
    'voiceCommandNotUnderstood': 'No entendí el comando. Intenta de nuevo.',
    'voiceMicPermissionDenied': 'Se necesita permiso de micrófono',
    'voiceSttUnavailable': 'Reconocimiento de voz no disponible en este dispositivo',
    'voiceTextFallbackTitle': 'Comando de voz (texto)',
    'voiceTextFallbackHint': 'Ej. entrada 200 pesos por sueldo',
    'staffTaskInvasiveDismiss': 'Recordar en 15 minutos',
    'staffTaskManageResponses': 'Respuestas del equipo',
    'staffTaskNoResponsesYet': 'Nadie ha respondido aún.',
    'staffTaskAdminChangeStatus': 'Cambiar estado',
    'staffTaskAdminStatusUpdated': 'Estado actualizado',
    'staffTaskEmployee': 'Empleado',
    'quickSalesSummaryTitle': 'Resumen de ventas',
    'quickSalesByShift': 'Ventas por turno',
    'quickCategoryDistribution': 'Distribución por categoría',
    'quickTopProductsToday': 'Más vendidos (hoy)',
    'quickTopProducts7d': 'Más vendidos (7 días)',
    'quickTopProducts30d': 'Más vendidos (30 días)',
    'quickNoData': 'Sin datos en este período.',
    'concept': 'Concepto',
    'accountCash': 'Caja',
    'accountBank': 'Banco',
    'period': 'Período',
    'periodToday': 'Hoy',
    'periodYesterday': 'Ayer',
    'periodThisWeek': 'Semana en curso',
    'periodLastWeek': 'Semana pasada',
    'periodThisMonth': 'Mes en curso',
    'periodLastMonth': 'Mes pasado',
    'startDate': 'Desde',
    'endDate': 'Hasta',
    'totalSales': 'Total ventas',
    'numberOfSales': 'Nº de ventas',
    'salesByPaymentMethod': 'Por método de pago',
    'topProductsByRevenue': 'Productos más vendidos',
    'product': 'Producto',
    'quantitySold': 'Cant. vendida',
    'revenue': 'Ingresos',
    'currentStock': 'Stock actual',
    'reorderPoint': 'Punto de reorden',
    'inventoryValue': 'Valor inventario',
    'lowStockAlert': 'Stock bajo',
    'recentMovements': 'Movimientos recientes',
    'reason': 'Motivo',
    'changeAmount': 'Cantidad',
    'reportSale': 'Venta',
    'reportPurchase': 'Compra',
    'reportWaste': 'Merma',
    'reportReconciliation': 'Conciliación',
    'discounts': 'Descuentos',
    'discountCode': 'Código de descuento',
    'discountByProduct': 'Descuento en producto',
    'percentageHint': 'Porcentaje (ej. 20)',
    'applyToProductsContaining': 'Aplicar a productos que contengan',
    'labelOptional': 'Etiqueta (opcional, ej. Día de la mujer)',
    'applyCode': 'Aplicar código',
    'applyProductDiscount': 'Descuento en producto',
    'codeApplied': 'Código aplicado',
    'invalidCode': 'Código inválido',
    'discountAppliedProduct': 'Descuento aplicado a productos que contengan',
    'discountCatalogTitle': 'Catálogo de descuentos',
    'discountPickFromList': 'Elegir del catálogo',
    'discountDisplayNameHint': 'Nombre en ticket (ej. Estudiantes)',
    'discountCatalogEmpty': 'No hay descuentos en el catálogo. Configúralos en administración.',
    'discountCatalogAppliedToast': 'Descuento aplicado: {name}',
    'discountInactiveLabel': 'Inactivo (no aparece en caja)',
    'discountShowAtRegister': 'Visible en caja',
    'discountSave': 'Guardar',
    'discountDeleteConfirmTitle': '¿Borrar este descuento?',
    'discountDeleteAction': 'Borrar',
    'discountCatalogSaved': 'Descuento guardado',
    'discountManagement': 'Códigos de descuento',
    'noDiscountsHint': 'No hay códigos. Toca + para agregar.',
    'newDiscount': 'Nuevo código',
    'editDiscount': 'Editar código',
    'discountType': 'Tipo de descuento',
    'discountTypeEmployee': 'Empleado',
    'discountTypePercentage': 'Porcentaje',
    'discountTypeEmployeeHint':
        'Usa la lista de precios especiales de empleado en cada producto.',
    'discountTypePercentageHint':
        'Aplica un porcentaje de descuento sobre el subtotal (sin bundles).',
    'discountCodeRequired': 'El código es obligatorio',
    'invalidPercentage': 'Introduce un porcentaje entre 1 y 100',
    'discountSaved': 'Código guardado',
    'deleteDiscount': 'Eliminar código',
    'deleteDiscountConfirm': '¿Eliminar el código',
    'importEmployeePrices': 'Importar precios empleado',
    'importEmployeePricesConfirm':
        'Se actualizarán los precios especiales de empleado desde el archivo de precios. ¿Continuar?',
    'importAction': 'Importar',
    'importEmployeePricesDone': 'Precios empleado actualizados en {n} productos.',
    'employeePrice': 'Precio empleado',
    'employeePriceOptional': 'Precio empleado (opcional)',
    'descriptionOptional': 'Descripción (opcional)',
    'active': 'Activo',
    'inactive': 'Inactivo',
    'delete': 'Eliminar',
    'save': 'Guardar',
    'employeeDiscountLabel': 'Precio empleado',
    'clearLocalSalesConfirmTitle': 'Vaciar ventas locales',
    'clearLocalSalesConfirmBody': '¿Borrar todas las ventas guardadas en este dispositivo? El historial local quedará vacío. La nube no se modifica.',
    'clear': 'Vaciar',
    'clearLocalSalesDone': 'Ventas locales borradas. El historial de este dispositivo está vacío.',
    'resetConfirmTitle': 'Restablecer datos locales',
    'resetConfirmBody': 'Se borrará todo lo que hay en este dispositivo (categorías, productos, ventas, turnos, etc.) y se cargará de nuevo desde la nube. ¿Continuar?',
    'resetAndSyncButton': 'Restablecer y sincronizar',
    'resettingAndSyncing': 'Borrando datos locales y sincronizando...',
    'resetSuccess': 'Datos restablecidos. Carga completa desde la nube.',
    'resetError': 'Error al sincronizar',
    'selectLanguage': 'Seleccionar idioma',
    'spanish': 'Español',
    'english': 'Inglés',
    'expectedCashInDrawer': 'Total que debería haber en caja',
    'enterCountedAmounts': 'Introduce las cantidades contadas',
    'totalCashInDrawer': 'Efectivo contado en caja',
    'totalCashInDrawerHint': 'Efectivo físico en caja',
    'salesDebit': 'Venta en débito',
    'salesCredit': 'Venta en crédito',
    'salesTransfer': 'Venta en transferencia',
    'submitCount': 'Ver resumen',
    'next': 'Siguiente',
    'closureSummary': 'Resumen del corte',
    'closeShiftTurnIdLine': 'Turno local · shift_id {id}',
    'closeShiftTurnIdsLocalCloud': 'Turno · SQLite id {l} · Supabase id {c}',
    'supabaseIdShort': 'Supabase',
    'closeShiftTurnIdHint':
        'Si otro equipo ya cerró en la nube un turno distinto, el número aquí puede no coincidir con Supabase. Usa «Registrar en la nube» con el turno abierto para alinear.',
    'closeShiftCloudLoading': 'Consultando turno en la nube…',
    'closeShiftCloudSectionTitle': 'Estado en la nube (Supabase)',
    'closeShiftCloudNoNetwork': 'Sin conexión: no se pudo verificar el turno en Supabase.',
    'closeShiftCloudQueryError': 'No se pudo consultar la nube: {msg}',
    'closeShiftCloudRowMissing':
        'No hay fila en Supabase con este shift_id. Pulsa «Registrar en la nube» en el menú con el turno abierto.',
    'closeShiftCloudAlreadyClosed':
        'En la nube este turno ya figura cerrado (fin: {at}). Cerrar otra vez aquí puede fallar o duplicar el cierre.',
    'closeShiftCloudOpenMismatch':
        'En la nube este dispositivo tiene abierto el turno {open}; en este equipo el turno local es {local}. Revisa o registra en la nube para alinear.',
    'closeShiftCloudAligned': 'Nube: turno abierto y coincide con este shift_id en este dispositivo.',
    'closeShiftCloudNoOpenForDevice':
        'En la nube no hay turno abierto para este dispositivo. Usa «Registrar en la nube» para actualizar el vínculo.',
    'closeCut': 'Cerrar corte',
    'goBack': 'Volver',
    'notesOptional': 'Notas (opcional)',
    'validAmount': 'Introduce una cantidad válida',
    'cardDeclaredRequired': 'Debe ingresar el monto reportado por la terminal en débito y crédito.',
    'cardMismatchTitle': 'Inconsistencia en tarjetas',
    'cardMismatchMessage': 'Lo declarado (débito + crédito) no coincide con las ventas en tarjeta registradas en el sistema.',
    'cardSalesSystem': 'Ventas en tarjeta (sistema)',
    'cardDeclared': 'Declarado (tarjetas)',
    'cardTerminalHint': 'Monto reportado por la terminal',
    'closureCorrect': 'Cuadre correcto',
    'closureIncorrectCardOnly': 'Cuadre incorrecto: inconsistencia en tarjetas',
    'closureIncorrectCashAndCard': 'Cuadre incorrecto: diferencia en caja {amount} e inconsistencia en tarjetas',
    'differenceInCash': 'Diferencia en caja: {amount}',
    'closeShiftNoOpen': 'No hay turno abierto',
    'closeShiftNoOpenHint':
        'Abre un turno explícitamente para vender o para hacer un corte. Ya no se abre un turno nuevo solo al cerrar el anterior.',
    'openShiftButton': 'Abrir turno',
    'openShiftStartingFundTitle': 'Abrir turno',
    'openShiftStartingFundBody': 'Indica el efectivo inicial en caja para este turno.',
    'posRegisterTitle': 'Caja / cajón',
    'posRegisterSubtitle': 'Este terminal opera en el cajón seleccionado (turnos y cortes).',
    'posRegisterChooseHint': 'Elige el cajón físico de esta tablet.',
    'posRegisterSaved': 'Cajón guardado. Vuelve a registrar en la nube si hace falta.',
    'continueOpenShiftButton': 'Continuar turno abierto en la nube',
    'continueOpenShiftTitle': 'Turnos abiertos en este cajón',
    'continueOpenShiftEmpty': 'No hay turnos abiertos en la nube para este cajón.',
    'continueOpenShiftLoading': 'Buscando turnos…',
    'continueOpenShiftLine': '{label} · Turno #{shift} · Inicio {started}',
    'posRequiresOpenShiftBanner':
        'No hay turno abierto. Debes abrir o continuar un turno en Cierre de caja para cobrar.',
    'posRequiresOpenShiftAction': 'Abrir turno',
    'posTopSellersStrip': 'Más vendidos',
    'posTopSellersEmpty':
        'Los más vendidos salen de las ventas en Supabase (tienda activa, últimos días) y requieren internet. Si hay ventas en la nube y esto sale vacío, falta aplicar en Supabase la migración 032 (función pos_top_selling_product_ids).',
    'closeShiftCloudCancelledApplied':
        'Ajuste nube aplicado: {count} venta(s) cancelada(s) en la nube no cuentan en este cierre.',
    'retry': 'Reintentar',
    'storesRegistersAdminTitle': 'Tiendas y cajones',
    'storesAdminAddStoreTitle': 'Nueva tienda',
    'storesAdminStoreNameLabel': 'Nombre de la tienda',
    'storesAdminEmpty': 'No hay tiendas en la nube.',
    'storesAdminStoreIdLine': 'Tienda id {id}',
    'storesAdminSaved': 'Guardado en la nube.',
    'storesAdminEditStoreTitle': 'Editar tienda',
    'storesAdminRegistersSubtitle': 'Cajones (pos_registers)',
    'storesAdminAddRegisterTitle': 'Nuevo cajón',
    'storesAdminRegisterLabelHint': 'Etiqueta (ej. Caja 1)',
    'storesAdminEditRegisterTitle': 'Editar cajón',
    'storesAdminDisplayOrderLabel': 'Orden de lista',
    'storesAdminNoRegisters': 'No hay cajones en esta tienda.',
    'storesAdminRegisterIdLine': 'Cajón id {id}',
    'storesAdminOrderLabel': 'Orden',
    'storesAdminActive': 'Activo',
    'storesAdminInactive': 'Inactivo',
    'storesAdminDeactivate': 'Desactivar cajón',
    'storesAdminActivate': 'Activar cajón',
    'adminLinkOpenShiftTitle': 'Enlazar a turno abierto',
    'adminLinkOpenShiftSubtitle':
        'Alinea esta tienda/cajón con un turno ya abierto en otra caja o tienda (Supabase).',
    'adminLinkOpenShiftLoading': 'Cargando turnos abiertos…',
    'adminLinkOpenShiftEmpty': 'No hay turnos abiertos en la nube.',
    'adminLinkOpenShiftRequiresLocalDb':
        'Esta acción solo está disponible en la app con base local (no en la consola web sin POS).',
    'adminLinkOpenShiftConfirmTitle': 'Enlazar terminal a este turno',
    'adminLinkOpenShiftConfirmBody':
        '¿Usar el turno #{id} en {store} · {register}? Se actualizarán tienda, cajón y registro del dispositivo en la nube.',
    'adminLinkOpenShiftUnlinkNote':
        'Este equipo dejará de usar el turno actual solo aquí. Ese turno sigue abierto en la nube hasta que se cierre con corte en su caja.',
    'adminLinkOpenShiftLinking': 'Enlazando…',
    'adminLinkOpenShiftLinkedOk': 'Terminal enlazado al turno. Revisa el POS o Cierre de caja.',
    'adminLinkOpenShiftLine': '{store} · {register} · Turno #{shift} · {started}',
    'adminLinkOpenShiftDeviceLine': 'Dispositivo: {device}',
  };

  static const Map<String, String> _en = {
    'appTitle': 'ICE POS',
    'menu': 'Menu',
    'language': 'Language',
    'languageNameEs': 'Español',
    'languageNameEn': 'English',
    'cancel': 'Cancel',
    'done': 'Done',
    'close': 'Close',
    'apply': 'Apply',
    'ok': 'OK',
    'error': 'Error',
    'cloudActive': 'Cloud active',
    'cloudNotConfigured': 'Cloud not configured',
    'syncWithSupabase': 'Sync with Supabase',
    'syncEnvHint': 'Set SUPABASE_URL and SUPABASE_ANON_KEY in .env',
    'setupSupabaseTitle': 'Connect to the cloud',
    'setupSupabaseSubtitle':
        'Enter your Supabase project URL and anon (public) key. They are saved on this device for automatic connection.',
    'setupSupabaseUrlLabel': 'Project URL (https://…supabase.co)',
    'setupSupabaseAnonKeyLabel': 'Anon key',
    'setupSupabaseConnect': 'Connect and sync',
    'setupSupabaseSkip': 'Continue offline',
    'setupSupabaseSchemaNote':
        'Tables and RLS policies must exist in your Supabase project. Run the SQL files in supabase/migrations (SQL Editor or CLI). The app cannot create the schema with the anon key alone.',
    'setupSupabaseInvalidUrl': 'URL must start with https:// and be a valid host.',
    'setupSupabaseConnecting': 'Connecting…',
    'setupSupabaseError': 'Could not connect. Check URL, key, and network.',
    'testConnection': 'Test connection',
    'connectionOk': 'Connection OK',
    'sync': 'Sync',
    'syncFromCloud': 'Sync from cloud',
    'sendToCloud': 'Send data to cloud',
    'sendToCloudSubtitle': 'Cloud will be the source of truth',
    'syncingFromCloud': 'Syncing from cloud...',
    'syncSuccess': 'Sync complete. Local data updated from cloud.',
    'syncError': 'Sync error',
    'syncStepStarting': 'Starting sync…',
    'syncStepDownloadingCategories': 'Downloading categories…',
    'syncStepDownloadingProducts': 'Downloading products and supplies…',
    'syncStepDownloadingRecipes': 'Downloading recipes and modifiers…',
    'syncStepDownloadingBundles': 'Downloading bundles and discounts…',
    'syncStepSavingLocal': 'Preparing local database…',
    'syncStepSavingCategories': 'Saving categories…',
    'syncStepSavingProducts': 'Saving products and supplies…',
    'syncStepSavingRecipes': 'Saving recipes and modifiers…',
    'syncStepSavingBundles': 'Saving bundles and discounts…',
    'syncStepFinishing': 'Finishing…',
    'syncStepProgress': 'Step {step}',
    'catalogMenuCacheLastSync': 'Menu cache (cloud): {when}',
    'catalogMenuCacheNever': 'Menu cache: not yet synced from cloud',
    'offlineBanner':
        'Offline: you can ring sales and use the register; menu and admin changes need internet.',
    'offlineRequiresInternet':
        'Connect to the internet to sync or edit the menu.',
    'sendingToCloud': 'Sending data to cloud...',
    'dataSentToCloud': 'Data sent to cloud',
    'loadMenuFromJson': 'Load menu from JSON',
    'loadMenuFromJsonSubtitle': 'Only when cloud is empty. If cloud has data, data syncs automatically.',
    'importRecipesFromJson': 'Import recipes (recetas_formato.json)',
    'importRecipesFromJsonSubtitle':
        'Updates local recipes and writes a CSV report. Modifier blocks in the JSON are not imported here.',
    'importRecipesConfirmTitle': 'Import recipes?',
    'importRecipesConfirmBody':
        'For each product in the JSON with ingredients: local recipes for that product are replaced. Products with an empty ingredient list are left unchanged. A CSV report will be saved.',
    'importRecipesPushCloudTitle': 'Upload recipes to cloud?',
    'importRecipesPushCloudBody':
        'Each updated product will be pushed to Supabase (recipes + product data). Requires connectivity.',
    'importRecipesPushCloudLocal': 'Local only',
    'importRecipesPushCloudYes': 'Yes, upload to cloud',
    'importingRecipes': 'Importing recipes...',
    'importRecipesDone': 'Import finished.',
    'importRecipesReportPath': 'CSV report:',
    'importRecipesReportClipboard': 'Report copied to clipboard.',
    'loadingMenuFromJson': 'Loading menu from JSON...',
    'loadingMenuAndSending': 'Loading menu and sending to cloud...',
    'menuReloaded': 'Menu reloaded (Bolis, Paletas, Nieves, Malteadas)',
    'reloadMenuConfirmTitle': 'Reload menu?',
    'reloadMenuConfirmBody': 'This will delete all categories and products that belong to a category, then reload from menu_reyes_nieves.json. Products without a category are kept.',
    'reload': 'Reload',
    'loadJsonNotAllowedTitle': 'Load from JSON not allowed',
    'loadJsonNotAllowedBody': 'Cloud already has data. To keep IDs in sync across devices, load from JSON is only allowed when the cloud is empty. On this device the menu updates automatically from the cloud.',
    'later': 'Later',
    'yesLoadAndSend': 'Yes, load and send',
    'updateAvailable': 'Update available',
    'download': 'Download',
    'operationLogTitle': 'Operation log',
    'operationLogSubtitle':
        'Level critical = failed write to local DB or Supabase. Also: sales, startup sync, Flutter/async, Riverpod. This device only.',
    'operationLogEmpty':
        'No entries yet. Failed checkouts or cloud write issues will appear here.',
    'shiftCloseDiagnosticsTitle': 'Shift close diagnostics',
    'shiftCloseDiagnosticsMenuSubtitle': 'Cloud events per device when closing a shift.',
    'shiftCloseDiagnosticsSubtitle':
        'Cloud events per device: movement pull when opening close shift, local close, and Supabase sync. Newest first.',
    'shiftCloseDiagnosticsEmpty':
        'No events yet. They appear when a device opens the close-shift screen (movement pull) or completes a close with cloud enabled.',
    'shiftCloseDiagnosticsDisabled': 'Cloud is not configured; nothing to show.',
    'cloudPosDiagnosticsTitle': 'Cloud · cash & devices',
    'shiftCloseEventsTab': 'Events',
    'devicesAndClosuresTab': 'Devices',
    'registerDeviceToCloudTitle': 'Register to cloud',
    'registerDeviceToCloudSubtitle':
        'Sends this terminal to the device list and links the open shift to this device ID (cashier and admin).',
    'registerDeviceToCloudOk': 'Device and open shift updated in the cloud.',
    'cloudDevicesEmpty':
        'No devices registered yet. Use “Register to cloud” on each POS while online.',
    'cloudDeviceLastSeen': 'Last seen',
    'cloudDeviceOpenShift': 'Open shift (cloud)',
    'cloudDeviceNoOpenShift': 'No open shift in the cloud for this device.',
    'cloudRemoteCloseShift': 'Remote close shift',
    'cloudRemoteCloseShiftHint':
        'Closes in Supabase only; the physical device may still have a local shift until it syncs or closes there. Expected cash uses cloud sales for this device in the shift window and CAJA movements for this shift_id.',
    'cloudSalesByDevice': 'Recent sales (cloud)',
    'cloudClosuresByDevice': 'Closures (cloud)',
    'cloudShiftClosedRemoteOk': 'Shift closed in the cloud.',
    'cloudNoSalesForDevice': 'No cloud sales for this device.',
    'cloudNoClosuresForDevice': 'No cloud closures for this device.',
    'storeLabel': 'Store',
    'exportOperationLog': 'Export and share (.txt)',
    'clearOperationLogConfirmTitle': 'Clear log?',
    'clearOperationLogConfirmBody':
        'All diagnostic entries on this device will be deleted.',
    'versionBuild': 'Version',
    'downloadHint': 'Tap "Download" to open the link and install the new version.',
    'downloadLinkCopied': 'Link copied. Paste it in your browser to download.',
    'alreadyLatestVersion': 'You already have the latest version.',
    'remoteUpdateRequestedTitle': 'Update requested',
    'remoteUpdateRequestedBodyDefault':
        'An administrator asked this register to check and install the latest app version when possible.',
    'remoteUpdateCheckNow': 'Check for update',
    'remoteUpdateAckLater': 'Later',
    'cloudRequestAppUpdate': 'Request update on device',
    'cloudRequestAppUpdateSubtitle':
        'The register will see a prompt next time they open the app or return to it (device needs internet).',
    'cloudClearUpdateRequest': 'Clear request',
    'cloudUpdateRequestSent': 'Update request saved for this device.',
    'cloudUpdateRequestCleared': 'Request cleared.',
    'cloudUpdateRequestMessageHint': 'Optional message for the register',
    'cloudUpdatePendingBadge': 'Update pending',
    'login': 'Log in',
    'username': 'Username',
    'emailOrUsername': 'Email or username',
    'password': 'Password',
    'signIn': 'Sign in',
    'invalidCredentials': 'Invalid username or password',
    'logout': 'Log out',
    'logoutHint': 'Sign out and return to login screen',
    'adminAccess': 'Admin access',
    'adminAccessHint': 'Only admins can access categories, products, supplies, shift close, and sync.',
    'enterAdminPin': 'Enter admin PIN',
    'setAdminPin': 'Set PIN (4 digits)',
    'invalidPin': 'Invalid PIN',
    'lockAsEmployee': 'Lock as employee',
    'lockAsEmployeeHint': 'POS and today\'s sales only',
    'salesToday': 'Sales today',
    'employeeMode': 'Employee mode',
    'pointOfSale': 'Point of Sale',
    'cart': 'Cart',
    'cartEmpty': 'Cart empty',
    'checkout': 'Checkout',
    'total': 'Total',
    'bundles': 'Bundles',
    'subtotalOther': 'Subtotal (other)',
    'discount': 'Discount',
    'removeDiscount': 'Remove discount',
    'applyDiscount': 'Apply discount',
    'scanDiscount': 'Scan discount',
    'quickSearchHint': 'Search by name…',
    'searchNoResults': 'No results',
    'park': 'Park',
    'processingSale': 'Processing sale...',
    'saleComplete': 'Sale complete',
    'ticketSent': 'Ticket sent to printer',
    'printError': 'Print error',
    'printingTicket': 'Printing ticket...',
    'reprintTicket': 'Reprint ticket',
    'saleCompletePrintError': 'Sale complete. Could not print ticket',
    'amountReceived': 'Amount received',
    'change': 'Change',
    'exactAmount': 'Exact amount',
    'confirmSale': 'Confirm sale',
    'cash': 'Cash',
    'card': 'Card',
    'transfer': 'Transfer',
    'verifyTransfer': 'Verify transfer in banking app before confirming.',
    'singlePayment': 'Single',
    'splitPayment': 'Split',
    'addPaymentMethod': 'Add payment',
    'splitPaymentRemaining': 'Remaining',
    'splitPaymentComplete': 'Fully covered',
    'splitPaymentOverpaid': 'Overpaid',
    'amount': 'Amount',
    'payment': 'Payment',
    'remove': 'Remove',
    'debit': 'Debit',
    'credit': 'Credit',
    'errorLoading': 'Error loading',
    'discountPercent': 'Discount',
    'productDiscountLabel': '% off',
    'supplyManagement': 'Supplies',
    'productManagement': 'Products',
    'categoryManagement': 'Categories',
    'categoryManagementSubtitle': 'Add, edit categories; assign products',
    'webAdminHomeTitle': 'Dashboard',
    'webAdminHomeSubtitle':
        'Manage catalog, inventory and sales via Supabase. Use the side menu for more options.',
    'webQuickAccess': 'Quick access',
    'drawerSectionGeneral': 'General',
    'drawerSectionDeviceCloud': 'Device & cloud',
    'drawerSectionCloudData': 'Cloud & data',
    'drawerSectionCatalog': 'Catalog & stock',
    'drawerSectionSalesReports': 'Sales & reports',
    'drawerSectionOrganization': 'Organization',
    'drawerSectionSupport': 'Support & diagnostics',
    'drawerSectionRegisterOps': 'Register & device',
    'drawerSectionAdvanced': 'Advanced',
    'bundleManagement': 'Bundles',
    'closeShift': 'Close shift',
    'printer': 'Printer',
    'printerSubtitle': 'Configure Bluetooth printer',
    'clearLocalSales': 'Clear local sales',
    'clearLocalSalesSubtitle': 'Deletes sales history on this device. Does not affect cloud.',
    'resetAndSync': 'Reset all and load from cloud',
    'resetAndSyncSubtitle': 'Deletes all local data (menu, sales, shifts) and reloads from Supabase.',
    'checkUpdate': 'Check for update',
    'checkUpdateSubtitle': 'See if a new app version is available',
    'thisDevice': 'This device',
    'inCloud': 'In cloud',
    'inventory': 'Inventory',
    'inventoryReconciliation': 'Inventory reconciliation',
    'inventoryReconciliationSubtitle':
        'Walk each supply and adjust quantity or level',
    'stockCountModeLabel': 'How to measure stock',
    'stockCountModeQuantity': 'Quantity (numeric)',
    'stockCountModeQualitative': 'Level (high / medium / low / critical)',
    'qualitativeLevelAlto': 'High',
    'qualitativeLevelMedio': 'Medium',
    'qualitativeLevelBajo': 'Low',
    'qualitativeLevelResurtir': 'Reorder',
    'qualitativeLevelCritico': 'Critical',
    'qualitativeUnitOption': 'Qualitative (level)',
    'reconcileCurrentStock': 'System stock: {qty} {unit}',
    'reconcileCurrentLevel': 'System level: {level}',
    'reconcileCountedQuantity': 'Physical count',
    'reconcileUnitLabel': 'Unit of measure',
    'reconcileModeQuantityHint':
        'Enter the counted quantity. The adjustment vs. system will be logged.',
    'reconcileModeQualitativeHint':
        'Pick the observed level. A numeric equivalent is kept for recipes.',
    'reconcileSelectLevel': 'Observed level',
    'reconcileSkip': 'Next without saving',
    'reconcileSaveAndContinue': 'Save and continue',
    'reconcileDone': 'Done',
    'reconcileEmpty': 'No supplies to reconcile.',
    'reconcileSaved': 'Inventory updated',
    'reconcileCloudSyncFailed':
        'Saved on device. Cloud upload failed; sync may restore the old value. ',
    'reconcileGroupLabel': 'Group: {name}',
    'reconcileGroupsCounter': 'Group {current} of {total}',
    'reconcileInGroupCounter': 'In this group: {current} / {total}',
    'reconcileOverallCounter': 'Overall: {current} / {total}',
    'reconcileRestart': 'Start over',
    'reconcileRestartConfirmTitle': 'Restart reconciliation?',
    'reconcileRestartConfirmBody':
        'Saved progress on this device will be cleared and you will return to the first supply in the first group.',
    'reconcilePreviousGroup': 'Previous group',
    'reconcileNextGroup': 'Next group',
    'reconcileSelectGroup': 'Choose group',
    'reconcileSearchHint': 'Search supplies across all groups…',
    'reconcileSearchNoResults': 'No supplies match your search.',
    'salesHistory': 'Sales history',
    'cancelSale': 'Cancel sale',
    'cancelMovement': 'Cancel movement',
    'cancelMovementConfirmBody': 'This movement will no longer count toward the cash count. This cannot be undone.',
    'cancelSaleConfirmTitle': 'Cancel sale',
    'cancelSaleConfirmBody': 'This sale will be deleted on this device only. Inventory is not restored (for test sales, adjust stock manually if needed).',
    'saleCancelled': 'Sale cancelled',
    'pendingCashierApprovalsTitle': 'Cashier approvals',
    'pendingCashierApprovalsSubtitle':
        'Movements, sale cancellations, and shift closes with large cash shortage',
    'pendingApprovalKindMovement': 'Movement',
    'pendingApprovalKindSaleCancel': 'Cancel sale',
    'pendingApprovalKindShiftClose': 'Shift close',
    'pendingApprovalApprove': 'Approve',
    'pendingApprovalReject': 'Reject',
    'pendingApprovalEmpty': 'No pending requests.',
    'pendingApprovalQueued':
        'Request sent. An administrator must approve it on this same device.',
    'pendingApprovalDuplicateShiftClose':
        'A shift close is already pending approval for this shift.',
    'pendingApprovalRejectedSnack': 'Request rejected',
    'pendingApprovalShiftIdLabel': 'Local shift',
    'pendingApprovalExpectedCashLabel': 'Expected cash in drawer',
    'pendingApprovalCashDifferenceLabel': 'Difference (declared − expected)',
    'pendingApprovalDeviceLine': 'Device: {id}',
    'pendingApprovalsDrawerSubtitle': '{count} pending',
    'salesHistoryAllDays': 'All',
    'salesHistoryPickDay': 'Choose day',
    'salesHistorySalesOnDate': 'Sales on {date}',
    'platformOrdersTitle': 'Platform orders',
    'platformOrdersSubtitle': 'Uber Eats by day (from cloud)',
    'platformOrdersUberEatsSection': 'Uber Eats',
    'platformOrdersByDayHint':
        'Orders whose time falls on the selected calendar day (device local time). Data comes from the platform_orders table in Supabase.',
    'platformOrdersRequiresCloud': 'Configure Supabase to load platform orders.',
    'platformOrdersLoadError': 'Could not load orders',
    'platformOrdersEmptyUberEats': 'No Uber Eats orders on this day.',
    'platformOrdersEmptyHint':
        'When your integration inserts rows into platform_orders (store_id, platform = uber_eats), they will show up here.',
    'platformOrdersNoSummary': 'No line-item summary.',
    'platformOrdersDayTotal': '{count} orders · day total',
    'reports': 'Reports',
    'reportsSubtitle': 'Sales and inventory statistics',
    'temperatureHistory': 'Freezer temperature',
    'temperatureHistorySubtitle':
        'History from cloud (temperature_readings table). Requires Supabase in .env.',
    'temperatureRange24h': '24 h',
    'temperatureRange7d': '7 days',
    'temperatureRange30d': '30 days',
    'temperatureSensorFilter': 'Sensor',
    'temperatureFreezerFilter': 'Freezer',
    'temperatureFreezerAll': 'All freezers',
    'temperatureFreezer1': 'Freezer 1 (left & right)',
    'temperatureFreezer2': 'Freezer 2',
    'temperatureSensorAll': 'All sensors',
    'temperatureUnknownSensor': 'No sensor',
    'temperatureSensorFreezer1Right': 'Freezer 1 — right',
    'temperatureSensorFreezer1Left': 'Freezer 1 — left',
    'temperatureSensorFreezer2Left': 'Freezer 2 — left',
    'temperatureNoData': 'No readings in this range.',
    'temperatureCloudRequired':
        'Set SUPABASE_URL and SUPABASE_ANON_KEY in .env to load temperature history.',
    'temperatureStats': 'Summary',
    'temperaturePoints': 'Readings',
    'temperatureFromTo': 'From — to',
    'temperatureMinMax': 'Min — max',
    'temperatureLastReading': 'Last reading: {value} °C — {at}',
    'salesReports': 'Sales',
    'inventoryReports': 'Inventory',
    'rayosXReport': 'Day X-Ray',
    'rayosXSubtitle': 'Sales summary and shift closures for the day',
    'closuresOfDay': 'Closures of the day',
    'noClosuresThatDay': 'No closures recorded for this day',
    'cutLabel': 'Closure',
    'openingTime': 'Opening',
    'closingTime': 'Closing',
    'startingFund': 'Starting fund',
    'expectedInDrawer': 'Expected in drawer',
    'declaredCash': 'Declared',
    'difference': 'Difference',
    'movements': 'Movements',
    'movementsCajaNetLabel': 'Movements (entries - exits)',
    'movementsSubtitle': 'Cash and bank entries and exits (not sales)',
    'movementLinkShift': 'Shift (cash)',
    'movementShiftNone': 'No shift',
    'movementShiftLabel': 'Shift #{id}',
    'entry': 'Entry',
    'exit': 'Exit',
    'addMovement': 'New movement',
    'staffTasksTitle': 'Tasks',
    'staffTasksAdminTitle': 'Staff tasks',
    'staffTasksMyTitle': 'My tasks',
    'staffTasksSubtitle': 'Schedule and track team tasks',
    'staffTaskNew': 'New task',
    'staffTaskEdit': 'Edit task',
    'staffTaskTitleLabel': 'Title',
    'staffTaskDescriptionLabel': 'Description (optional)',
    'staffTaskScheduledAt': 'Due date and time',
    'staffTaskNotifyAt': 'Reminder (optional)',
    'staffTaskNotifyNow': 'Send reminder now',
    'staffTaskCancel': 'Cancel task',
    'staffTaskCancelled': 'Cancelled',
    'staffTaskMarkDone': 'Done',
    'staffTaskMarkSkipped': 'Skipped',
    'staffTaskComment': 'Comment',
    'staffTaskCommentOptional': 'Comment (optional)',
    'staffTaskStatusPending': 'Pending',
    'staffTaskStatusDone': 'Done',
    'staffTaskStatusSkipped': 'Skipped',
    'staffTaskDue': 'Due',
    'staffTaskResponses': 'Responses',
    'staffTaskNoTasks': 'No tasks',
    'staffTaskCloudRequired': 'Requires cloud connection',
    'staffTaskSaved': 'Task saved',
    'staffTaskSendDueReminders': 'Send scheduled reminders',
    'staffTaskRemindersResult': 'Reminders: {tasks} task(s), {push} push sent',
    'staffTaskDueAlert': 'You have {n} task(s) to complete.',
    'staffTaskStatusInProgress': 'In progress',
    'staffTaskStatusScheduled': 'Scheduled',
    'staffTaskMarkInProgress': 'Start',
    'staffTaskMarkOmitted': 'Omit',
    'staffTaskCommentRequired': 'Reason (required)',
    'staffTaskInvasiveTitle': 'Pending tasks',
    'staffTaskInvasiveSubtitle': 'Complete {n} activity(ies) before continuing',
    'staffTaskPendingAlertTooltip': '{n} pending task(s). Tap to view',
    'voiceMicTooltip': 'Voice movement',
    'voiceListening': 'Listening…',
    'voiceListeningHint': 'Say e.g. entry 200 pesos for payroll',
    'voiceContinue': 'Continue',
    'voiceConfirmTitle': 'Confirm movement',
    'voiceConfirmIncomplete': 'Fill in missing fields before registering.',
    'voiceAmountLabel': 'Amount',
    'voiceRegister': 'Register',
    'voiceInvalidAmount': 'Invalid amount',
    'voiceMissingReason': 'Enter a concept',
    'voiceCommandNotUnderstood': 'Command not understood. Try again.',
    'voiceMicPermissionDenied': 'Microphone permission required',
    'voiceSttUnavailable': 'Speech recognition unavailable on this device',
    'voiceTextFallbackTitle': 'Voice command (text)',
    'voiceTextFallbackHint': 'E.g. entry 200 pesos for payroll',
    'staffTaskInvasiveDismiss': 'Remind me in 15 minutes',
    'staffTaskManageResponses': 'Team responses',
    'staffTaskNoResponsesYet': 'No responses yet.',
    'staffTaskAdminChangeStatus': 'Change status',
    'staffTaskAdminStatusUpdated': 'Status updated',
    'staffTaskEmployee': 'Employee',
    'quickSalesSummaryTitle': 'Sales summary',
    'quickSalesByShift': 'Sales by shift',
    'quickCategoryDistribution': 'Sales by category',
    'quickTopProductsToday': 'Top products (today)',
    'quickTopProducts7d': 'Top products (7 days)',
    'quickTopProducts30d': 'Top products (30 days)',
    'quickNoData': 'No data in this period.',
    'concept': 'Concept',
    'accountCash': 'Cash',
    'accountBank': 'Bank',
    'period': 'Period',
    'periodToday': 'Today',
    'periodYesterday': 'Yesterday',
    'periodThisWeek': 'This week',
    'periodLastWeek': 'Last week',
    'periodThisMonth': 'This month',
    'periodLastMonth': 'Last month',
    'startDate': 'From',
    'endDate': 'To',
    'totalSales': 'Total sales',
    'numberOfSales': 'No. of sales',
    'salesByPaymentMethod': 'By payment method',
    'topProductsByRevenue': 'Top products',
    'product': 'Product',
    'quantitySold': 'Qty sold',
    'revenue': 'Revenue',
    'currentStock': 'Current stock',
    'reorderPoint': 'Reorder point',
    'inventoryValue': 'Inventory value',
    'lowStockAlert': 'Low stock',
    'recentMovements': 'Recent movements',
    'reason': 'Reason',
    'changeAmount': 'Amount',
    'reportSale': 'Sale',
    'reportPurchase': 'Purchase',
    'reportWaste': 'Waste',
    'reportReconciliation': 'Reconciliation',
    'discounts': 'Discounts',
    'discountCode': 'Discount code',
    'discountByProduct': 'Discount by product',
    'percentageHint': 'Percentage (e.g. 20)',
    'applyToProductsContaining': 'Apply to products containing',
    'labelOptional': 'Label (optional, e.g. Women\'s Day)',
    'applyCode': 'Apply code',
    'applyProductDiscount': 'Product discount',
    'codeApplied': 'Code applied',
    'invalidCode': 'Invalid code',
    'discountAppliedProduct': 'Discount applied to products containing',
    'discountCatalogTitle': 'Discount catalog',
    'discountPickFromList': 'Pick from catalog',
    'discountDisplayNameHint': 'Receipt label (e.g. Students)',
    'discountCatalogEmpty': 'No discounts in catalog. Add them in admin.',
    'discountCatalogAppliedToast': 'Discount applied: {name}',
    'discountInactiveLabel': 'Inactive (hidden at register)',
    'discountShowAtRegister': 'Shown at register',
    'discountSave': 'Save',
    'discountDeleteConfirmTitle': 'Delete this discount?',
    'discountDeleteAction': 'Delete',
    'discountCatalogSaved': 'Discount saved',
    'discountManagement': 'Discount codes',
    'noDiscountsHint': 'No codes yet. Tap + to add.',
    'newDiscount': 'New code',
    'editDiscount': 'Edit code',
    'discountType': 'Discount type',
    'discountTypeEmployee': 'Employee',
    'discountTypePercentage': 'Percentage',
    'discountTypeEmployeeHint':
        'Uses the special employee price list on each product.',
    'discountTypePercentageHint':
        'Applies a percentage off the standalone subtotal (excludes bundles).',
    'discountCodeRequired': 'Code is required',
    'invalidPercentage': 'Enter a percentage between 1 and 100',
    'discountSaved': 'Code saved',
    'deleteDiscount': 'Delete code',
    'deleteDiscountConfirm': 'Delete code',
    'importEmployeePrices': 'Import employee prices',
    'importEmployeePricesConfirm':
        'Update employee special prices from the price file. Continue?',
    'importAction': 'Import',
    'importEmployeePricesDone': 'Employee prices updated on {n} products.',
    'employeePrice': 'Employee price',
    'employeePriceOptional': 'Employee price (optional)',
    'descriptionOptional': 'Description (optional)',
    'active': 'Active',
    'inactive': 'Inactive',
    'delete': 'Delete',
    'save': 'Save',
    'employeeDiscountLabel': 'Employee price',
    'clearLocalSalesConfirmTitle': 'Clear local sales',
    'clearLocalSalesConfirmBody': 'Delete all sales on this device? Local history will be empty. Cloud is not modified.',
    'clear': 'Clear',
    'clearLocalSalesDone': 'Local sales cleared. History on this device is empty.',
    'resetConfirmTitle': 'Reset local data',
    'resetConfirmBody': 'All data on this device (categories, products, sales, shifts, etc.) will be deleted and reloaded from the cloud. Continue?',
    'resetAndSyncButton': 'Reset and sync',
    'resettingAndSyncing': 'Clearing local data and syncing...',
    'resetSuccess': 'Data reset. Full load from cloud.',
    'resetError': 'Sync error',
    'selectLanguage': 'Select language',
    'spanish': 'Español',
    'english': 'English',
    'expectedCashInDrawer': 'Expected total in drawer',
    'enterCountedAmounts': 'Enter counted amounts',
    'totalCashInDrawer': 'Cash counted in drawer',
    'totalCashInDrawerHint': 'Physical cash in drawer',
    'salesDebit': 'Sales (debit)',
    'salesCredit': 'Sales (credit)',
    'salesTransfer': 'Sales (transfer)',
    'submitCount': 'View summary',
    'next': 'Next',
    'closureSummary': 'Closure summary',
    'closeShiftTurnIdLine': 'Local shift · shift_id {id}',
    'closeShiftTurnIdsLocalCloud': 'Shift · SQLite id {l} · Supabase id {c}',
    'supabaseIdShort': 'Supabase',
    'closeShiftTurnIdHint':
        'If another device closed a different shift in the cloud, this id may not match Supabase. Use “Register in cloud” while the shift is open to align.',
    'closeShiftCloudLoading': 'Checking shift in the cloud…',
    'closeShiftCloudSectionTitle': 'Cloud status (Supabase)',
    'closeShiftCloudNoNetwork': 'Offline: could not verify the shift in Supabase.',
    'closeShiftCloudQueryError': 'Cloud query failed: {msg}',
    'closeShiftCloudRowMissing':
        'There is no Supabase row for this shift_id. Tap “Register in cloud” in the menu while the shift is open.',
    'closeShiftCloudAlreadyClosed':
        'This shift is already marked closed in the cloud (ended: {at}). Closing again here may fail or duplicate the closure.',
    'closeShiftCloudOpenMismatch':
        'In the cloud this device has shift {open} open; on this device the local shift is {local}. Register in cloud or align before closing.',
    'closeShiftCloudAligned': 'Cloud: open shift matches this shift_id for this device.',
    'closeShiftCloudNoOpenForDevice':
        'No open shift in the cloud for this device. Use “Register in cloud” to refresh the link.',
    'closeCut': 'Close cut',
    'goBack': 'Go back',
    'notesOptional': 'Notes (optional)',
    'validAmount': 'Enter a valid amount',
    'cardDeclaredRequired': 'You must enter the amount reported by the terminal for debit and credit.',
    'cardMismatchTitle': 'Card mismatch',
    'cardMismatchMessage': 'Declared amount (debit + credit) does not match card sales recorded in the system.',
    'cardSalesSystem': 'Card sales (system)',
    'cardDeclared': 'Declared (cards)',
    'cardTerminalHint': 'Amount reported by terminal',
    'closureCorrect': 'Closure correct',
    'closureIncorrectCardOnly': 'Closure incorrect: card mismatch',
    'closureIncorrectCashAndCard': 'Closure incorrect: cash difference {amount} and card mismatch',
    'differenceInCash': 'Cash difference: {amount}',
    'closeShiftNoOpen': 'No shift is open',
    'closeShiftNoOpenHint':
        'Open a shift explicitly to sell or to run a close-out. A new shift is no longer opened automatically when you close the previous one.',
    'openShiftButton': 'Open shift',
    'openShiftStartingFundTitle': 'Open shift',
    'openShiftStartingFundBody': 'Enter the starting cash in the drawer for this shift.',
    'posRegisterTitle': 'Register / drawer',
    'posRegisterSubtitle': 'This device operates on the selected drawer (shifts and closeout).',
    'posRegisterChooseHint': 'Pick the physical checkout this tablet uses.',
    'posRegisterSaved': 'Register saved. Use “Register in cloud” again if needed.',
    'continueOpenShiftButton': 'Continue open shift from cloud',
    'continueOpenShiftTitle': 'Open shifts on this register',
    'continueOpenShiftEmpty': 'No open shifts in the cloud for this register.',
    'continueOpenShiftLoading': 'Looking up shifts…',
    'continueOpenShiftLine': '{label} · Shift #{shift} · Started {started}',
    'posRequiresOpenShiftBanner':
        'No shift is open. Open or continue a shift from Close shift before checking out.',
    'posRequiresOpenShiftAction': 'Open shift',
    'posTopSellersStrip': 'Top sellers',
    'posTopSellersEmpty':
        'Top sellers use Supabase sales (active store, recent days) and require internet. If cloud has sales but this is empty, apply migration 032 (pos_top_selling_product_ids) in Supabase.',
    'closeShiftCloudCancelledApplied':
        'Cloud adjustment applied: {count} cloud-cancelled sale(s) are excluded from this closeout.',
    'retry': 'Retry',
    'storesRegistersAdminTitle': 'Stores and registers',
    'storesAdminAddStoreTitle': 'New store',
    'storesAdminStoreNameLabel': 'Store name',
    'storesAdminEmpty': 'No stores in the cloud.',
    'storesAdminStoreIdLine': 'Store id {id}',
    'storesAdminSaved': 'Saved to cloud.',
    'storesAdminEditStoreTitle': 'Edit store',
    'storesAdminRegistersSubtitle': 'Registers (pos_registers)',
    'storesAdminAddRegisterTitle': 'New register',
    'storesAdminRegisterLabelHint': 'Label (e.g. Register 1)',
    'storesAdminEditRegisterTitle': 'Edit register',
    'storesAdminDisplayOrderLabel': 'Display order',
    'storesAdminNoRegisters': 'No registers for this store.',
    'storesAdminRegisterIdLine': 'Register id {id}',
    'storesAdminOrderLabel': 'Order',
    'storesAdminActive': 'Active',
    'storesAdminInactive': 'Inactive',
    'storesAdminDeactivate': 'Deactivate register',
    'storesAdminActivate': 'Activate register',
    'adminLinkOpenShiftTitle': 'Link to open shift',
    'adminLinkOpenShiftSubtitle':
        'Align this device’s store/register with a shift already open on another register or store.',
    'adminLinkOpenShiftLoading': 'Loading open shifts…',
    'adminLinkOpenShiftEmpty': 'No open shifts in the cloud.',
    'adminLinkOpenShiftRequiresLocalDb':
        'This action is only available in the app with a local database (not web admin without POS).',
    'adminLinkOpenShiftConfirmTitle': 'Link device to this shift',
    'adminLinkOpenShiftConfirmBody':
        'Use shift #{id} at {store} · {register}? Store, register, and device record in the cloud will be updated.',
    'adminLinkOpenShiftUnlinkNote':
        'This device will stop using the current shift locally only. That shift stays open in the cloud until it is closed properly at its register.',
    'adminLinkOpenShiftLinking': 'Linking…',
    'adminLinkOpenShiftLinkedOk': 'Device linked to the shift. Check POS or Close shift.',
    'adminLinkOpenShiftLine': '{store} · {register} · Shift #{shift} · {started}',
    'adminLinkOpenShiftDeviceLine': 'Device: {device}',
  };
}
