class DatabaseTables {
  // Table names
  static const String deviceConfig = 'device_config';
  static const String shops = 'shops';
  static const String itemFamilies = 'item_families';
  static const String items = 'items';
  static const String attributeDefinitions = 'attribute_definitions';
  static const String itemAttributes = 'item_attributes';
  static const String transactions = 'transactions';
  static const String transactionLines = 'transaction_lines';
  static const String syncHistory = 'sync_history';
  static const String priceHistory = 'price_history';

  // Create table scripts
  static const String createDeviceConfigTable = '''
    CREATE TABLE $deviceConfig (
      deviceId TEXT PRIMARY KEY,
      shopId TEXT NOT NULL,
      mode TEXT NOT NULL,
      isConfigured INTEGER NOT NULL DEFAULT 0,
      currentTrxCounter INTEGER NOT NULL DEFAULT 1,
      currentShopOpenDate TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''';

  static const String createShopsTable = '''
    CREATE TABLE $shops (
      shopId TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      familyDigits INTEGER NOT NULL,
      itemDigits INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      isOpen INTEGER NOT NULL DEFAULT 0,
      currentShopOpenDate TEXT NOT NULL
    )
  ''';

  static const String createItemFamiliesTable = '''
    CREATE TABLE $itemFamilies (
      familyId TEXT PRIMARY KEY,
      shopId TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (shopId) REFERENCES $shops (shopId)
    )
  ''';

  static const String createItemsTable = '''
    CREATE TABLE $items (
      itemId TEXT PRIMARY KEY,
      familyId TEXT NOT NULL,
      shopId TEXT NOT NULL,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      quantity INTEGER NOT NULL,
      minQuantity INTEGER NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      FOREIGN KEY (familyId) REFERENCES $itemFamilies (familyId),
      FOREIGN KEY (shopId) REFERENCES $shops (shopId)
    )
  ''';

  static const String createAttributeDefinitionsTable = '''
    CREATE TABLE $attributeDefinitions (
      attributeId INTEGER PRIMARY KEY AUTOINCREMENT,
      familyId TEXT NOT NULL,
      name TEXT NOT NULL,
      dataType TEXT NOT NULL,
      isRequired INTEGER NOT NULL DEFAULT 0,
      dropdownOptions TEXT,
      displayOrder INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (familyId) REFERENCES $itemFamilies (familyId)
    )
  ''';

  static const String createItemAttributesTable = '''
    CREATE TABLE $itemAttributes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      itemId TEXT NOT NULL,
      attributeId INTEGER NOT NULL,
      valueText TEXT,
      valueNumber REAL,
      valueDate TEXT,
      valueBoolean INTEGER,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      FOREIGN KEY (itemId) REFERENCES $items (itemId),
      FOREIGN KEY (attributeId) REFERENCES $attributeDefinitions (attributeId)
    )
  ''';

  static const String createTransactionsTable = '''
    CREATE TABLE $transactions (
      transactionId TEXT PRIMARY KEY,
      deviceId TEXT NOT NULL,
      shopId TEXT NOT NULL,
      status TEXT NOT NULL,
      customerName TEXT,
      customerPhone TEXT,
      totalAmount REAL NOT NULL,
      createdAt TEXT NOT NULL,
      shopOpenDate TEXT NOT NULL,
      isSynced INTEGER NOT NULL DEFAULT 0,
      syncedAt TEXT,
      FOREIGN KEY (shopId) REFERENCES $shops (shopId)
    )
  ''';

  static const String createTransactionLinesTable = '''
    CREATE TABLE $transactionLines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transactionId TEXT NOT NULL,
      itemId TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unitPrice REAL NOT NULL,
      lineTotal REAL NOT NULL,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (transactionId) REFERENCES $transactions (transactionId)
    )
  ''';

  static const String createSyncHistoryTable = '''
    CREATE TABLE $syncHistory (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fromDeviceId TEXT NOT NULL,
      toDeviceId TEXT NOT NULL,
      dateTime TEXT NOT NULL,
      status TEXT NOT NULL,
      transactionsCount INTEGER NOT NULL,
      details TEXT
    )
  ''';

  static const String createPriceHistoryTable = '''
    CREATE TABLE $priceHistory (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      itemId TEXT NOT NULL,
      oldPrice REAL NOT NULL,
      newPrice REAL NOT NULL,
      changedAt TEXT NOT NULL,
      changedBy TEXT NOT NULL,
      FOREIGN KEY (itemId) REFERENCES $items (itemId)
    )
  ''';

  // Indexes
  static const List<String> createIndexes = [
    'CREATE INDEX idx_items_family ON $items(familyId)',
    'CREATE INDEX idx_items_shop ON $items(shopId)',
    'CREATE INDEX idx_item_attributes_item ON $itemAttributes(itemId)',
    'CREATE INDEX idx_item_attributes_attr ON $itemAttributes(attributeId)',
    'CREATE INDEX idx_attr_def_family ON $attributeDefinitions(familyId)',
    'CREATE INDEX idx_transactions_device ON $transactions(deviceId)',
    'CREATE INDEX idx_transactions_shop ON $transactions(shopId)',
    'CREATE INDEX idx_transactions_date ON $transactions(shopOpenDate)',
    'CREATE INDEX idx_transaction_lines_trx ON $transactionLines(transactionId)',
    'CREATE INDEX idx_sync_history_device ON $syncHistory(fromDeviceId)',
  ];

  // All create table statements
  static List<String> get allCreateStatements => [
        createDeviceConfigTable,
        createShopsTable,
        createItemFamiliesTable,
        createItemsTable,
        createAttributeDefinitionsTable,
        createItemAttributesTable,
        createTransactionsTable,
        createTransactionLinesTable,
        createSyncHistoryTable,
        createPriceHistoryTable,
        ...createIndexes,
      ];
}