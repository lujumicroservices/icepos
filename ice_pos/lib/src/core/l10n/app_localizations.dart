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
  String get exportOperationLog => _('exportOperationLog');
  String get clearOperationLogConfirmTitle => _('clearOperationLogConfirmTitle');
  String get clearOperationLogConfirmBody => _('clearOperationLogConfirmBody');
  String get versionBuild => _('versionBuild');
  String get downloadHint => _('downloadHint');
  String get downloadLinkCopied => _('downloadLinkCopied');

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
  String get errorLoading => _('errorLoading');
  String get discountPercent => _('discountPercent');
  String get productDiscountLabel => _('productDiscountLabel');

  // Drawer
  String get supplyManagement => _('supplyManagement');
  String get productManagement => _('productManagement');
  String get categoryManagement => _('categoryManagement');
  String get categoryManagementSubtitle => _('categoryManagementSubtitle');
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
  String get cancelSale => _('cancelSale');
  String get cancelSaleConfirmTitle => _('cancelSaleConfirmTitle');
  String get cancelSaleConfirmBody => _('cancelSaleConfirmBody');
  String get saleCancelled => _('saleCancelled');

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
  String get entry => _('entry');
  String get exit => _('exit');
  String get addMovement => _('addMovement');
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
        'Errores de venta y sincronización con la nube (solo en este dispositivo).',
    'operationLogEmpty':
        'No hay entradas todavía. Si una venta falla o la nube no guarda la venta, aparecerá aquí.',
    'exportOperationLog': 'Exportar y compartir (.txt)',
    'clearOperationLogConfirmTitle': '¿Borrar el registro?',
    'clearOperationLogConfirmBody':
        'Se eliminarán todas las entradas de diagnóstico de este dispositivo.',
    'versionBuild': 'Versión',
    'downloadHint': 'Pulsa "Descargar" para abrir el enlace e instalar la nueva versión.',
    'downloadLinkCopied': 'Enlace copiado. Pégalo en el navegador para descargar.',
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
    'errorLoading': 'Error al cargar',
    'discountPercent': 'Descuento',
    'productDiscountLabel': '% en',
    'supplyManagement': 'Insumos',
    'productManagement': 'Productos',
    'categoryManagement': 'Categorías',
    'categoryManagementSubtitle': 'Crear y editar categorías; asignar productos',
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
    'cancelSaleConfirmTitle': 'Cancelar venta',
    'cancelSaleConfirmBody': 'Se borrará esta venta solo en este dispositivo. El inventario no se revierte (si fue una venta de prueba, ajusta el stock manualmente si hace falta).',
    'saleCancelled': 'Venta cancelada',
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
    'entry': 'Entrada',
    'exit': 'Salida',
    'addMovement': 'Nuevo movimiento',
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
        'Sale and cloud sync issues (this device only).',
    'operationLogEmpty':
        'No entries yet. Failed checkouts or cloud write issues will appear here.',
    'exportOperationLog': 'Export and share (.txt)',
    'clearOperationLogConfirmTitle': 'Clear log?',
    'clearOperationLogConfirmBody':
        'All diagnostic entries on this device will be deleted.',
    'versionBuild': 'Version',
    'downloadHint': 'Tap "Download" to open the link and install the new version.',
    'downloadLinkCopied': 'Link copied. Paste it in your browser to download.',
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
    'saleCompletePrintError': 'Sale complete. Could not print ticket',
    'amountReceived': 'Amount received',
    'change': 'Change',
    'exactAmount': 'Exact amount',
    'confirmSale': 'Confirm sale',
    'cash': 'Cash',
    'card': 'Card',
    'transfer': 'Transfer',
    'verifyTransfer': 'Verify transfer in banking app before confirming.',
    'debit': 'Debit',
    'credit': 'Credit',
    'errorLoading': 'Error loading',
    'discountPercent': 'Discount',
    'productDiscountLabel': '% off',
    'supplyManagement': 'Supplies',
    'productManagement': 'Products',
    'categoryManagement': 'Categories',
    'categoryManagementSubtitle': 'Add, edit categories; assign products',
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
    'cancelSaleConfirmTitle': 'Cancel sale',
    'cancelSaleConfirmBody': 'This sale will be deleted on this device only. Inventory is not restored (for test sales, adjust stock manually if needed).',
    'saleCancelled': 'Sale cancelled',
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
    'entry': 'Entry',
    'exit': 'Exit',
    'addMovement': 'New movement',
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
  };
}
