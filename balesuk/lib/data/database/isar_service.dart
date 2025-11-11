import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_models.dart';

class IsarService {
  static final IsarService instance = IsarService._init();
  Isar? _isar;

  IsarService._init();

  Future<Isar> get isar async {
    if (_isar != null) return _isar!;
    _isar = await _initDB();
    return _isar!;
  }

  Future<Isar> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();

    return await Isar.open(
      [
        DeviceConfigSchema,
        ShopSchema,
        ItemFamilySchema,
        ItemSchema,
        AttributeDefinitionSchema,
        ItemAttributeSchema,
        TransactionSchema,
        TransactionLineSchema,
        SyncHistorySchema,
        PriceHistorySchema,
      ],
      directory: dir.path,
      name: 'balesuk',
    );
  }

  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }

  // ==================== DEVICE CONFIG QUERIES ====================

  Future<DeviceConfig?> getDeviceConfig() async {
    final db = await isar;
    return await db.deviceConfigs.where().findFirst();
  }

  Future<void> saveDeviceConfig(DeviceConfig config) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.deviceConfigs.put(config);
    });
  }

  Future<void> updateTrxCounter(String deviceId, int newCounter) async {
    final db = await isar;
    final config = await db.deviceConfigs
        .filter()
        .deviceIdEqualTo(deviceId)
        .findFirst();

    if (config != null) {
      config.currentTrxCounter = newCounter;
      await db.writeTxn(() async {
        await db.deviceConfigs.put(config);
      });
    }
  }

  Future<void> resetTrxCounterForNewDay(
      String deviceId, String newDate) async {
    final db = await isar;
    final config = await db.deviceConfigs
        .filter()
        .deviceIdEqualTo(deviceId)
        .findFirst();

    if (config != null) {
      config.currentTrxCounter = 1;
      config.currentShopOpenDate = newDate;
      await db.writeTxn(() async {
        await db.deviceConfigs.put(config);
      });
    }
  }

  // ==================== SHOP QUERIES ====================

  Future<Shop?> getShop(String shopId) async {
    final db = await isar;
    return await db.shops.filter().shopIdEqualTo(shopId).findFirst();
  }

  Future<void> saveShop(Shop shop) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.shops.put(shop);
    });
  }

  Future<void> updateShopStatus(
      String shopId, bool isOpen, String currentDate) async {
    final db = await isar;
    final shop = await getShop(shopId);

    if (shop != null) {
      shop.isOpen = isOpen;
      shop.currentShopOpenDate = currentDate;
      await db.writeTxn(() async {
        await db.shops.put(shop);
      });
    }
  }

  // ==================== ITEM FAMILY QUERIES ====================

  Stream<List<ItemFamily>> watchAllFamilies(String shopId) async* {
    final db = await isar;
    yield* db.itemFamilys
        .filter()
        .shopIdEqualTo(shopId)
        .sortByName()
        .watch(fireImmediately: true);
  }

  Future<List<ItemFamily>> getAllFamilies(String shopId) async {
    final db = await isar;
    return await db.itemFamilys
        .filter()
        .shopIdEqualTo(shopId)
        .sortByName()
        .findAll();
  }

  Future<ItemFamily?> getFamilyById(String familyId) async {
    final db = await isar;
    return await db.itemFamilys.filter().familyIdEqualTo(familyId).findFirst();
  }

  Future<void> saveFamily(ItemFamily family) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.itemFamilys.put(family);
    });
  }

  Future<int> getFamilyItemCount(String familyId) async {
    final db = await isar;
    return await db.items.filter().familyIdEqualTo(familyId).count();
  }

  Future<int> getNextFamilySequence(String shopId) async {
    final families = await getAllFamilies(shopId);
    if (families.isEmpty) return 1;

    final maxId = families
        .map((f) => int.tryParse(f.familyId) ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return maxId + 1;
  }

  // ==================== ITEM QUERIES ====================

  Stream<List<Item>> watchAllItems(String shopId) async* {
    final db = await isar;
    yield* db.items
        .filter()
        .shopIdEqualTo(shopId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<List<Item>> getAllItems(String shopId) async {
    final db = await isar;
    return await db.items.filter().shopIdEqualTo(shopId).findAll();
  }

  Future<List<Item>> getItemsByFamily(String familyId) async {
    final db = await isar;
    return await db.items
        .filter()
        .familyIdEqualTo(familyId)
        .sortByName()
        .findAll();
  }

  Future<Item?> getItemById(String itemId) async {
    final db = await isar;
    return await db.items.filter().itemIdEqualTo(itemId).findFirst();
  }

  Future<void> saveItem(Item item) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.items.put(item);
    });
  }

  Future<void> saveMultipleItems(List<Item> items) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.items.putAll(items);
    });
  }

  Future<void> updateItemQuantity(String itemId, int delta) async {
    final db = await isar;
    final item = await getItemById(itemId);

    if (item != null) {
      item.quantity += delta;
      item.updatedAt = DateTime.now();
      await db.writeTxn(() async {
        await db.items.put(item);
      });
    }
  }

  Future<List<Item>> searchItems(String shopId, String query) async {
    final db = await isar;
    final lowerQuery = query.toLowerCase();

    return await db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .group((q) => q
            .nameContains(query, caseSensitive: false)
            .or()
            .itemIdContains(query))
        .findAll();
  }

  Future<int> getLowStockCount(String shopId) async {
    final db = await isar;
    final allItems = await getAllItems(shopId);
    return allItems.where((item) => item.isLowStock).length;
  }

  Future<int> getNextItemSequence(String familyId, int itemDigits) async {
    final items = await getItemsByFamily(familyId);
    if (items.isEmpty) return 1;

    final sequences = items.map((item) {
      final itemPart = item.itemId.substring(item.itemId.length - itemDigits);
      return int.tryParse(itemPart) ?? 0;
    }).toList();

    final maxSeq = sequences.reduce((a, b) => a > b ? a : b);
    return maxSeq + 1;
  }

  // ==================== ATTRIBUTE QUERIES ====================

  Future<List<AttributeDefinition>> getAttributesByFamily(
      String familyId) async {
    final db = await isar;
    return await db.attributeDefinitions
        .filter()
        .familyIdEqualTo(familyId)
        .sortByDisplayOrder()
        .findAll();
  }

  Future<void> saveAttributeDefinition(AttributeDefinition attr) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.attributeDefinitions.put(attr);
    });
  }

  Future<void> saveMultipleAttributeDefinitions(
      List<AttributeDefinition> attrs) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.attributeDefinitions.putAll(attrs);
    });
  }

  Future<List<ItemAttribute>> getItemAttributes(String itemId) async {
    final db = await isar;
    return await db.itemAttributes.filter().itemIdEqualTo(itemId).findAll();
  }

  Future<void> saveItemAttribute(ItemAttribute attr) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.itemAttributes.put(attr);
    });
  }

  Future<void> saveMultipleItemAttributes(List<ItemAttribute> attrs) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.itemAttributes.putAll(attrs);
    });
  }

  // ==================== TRANSACTION QUERIES ====================

  Stream<List<Transaction>> watchTodayTransactions(
      String deviceId, String date) async* {
    final db = await isar;
    yield* db.transactions
        .filter()
        .deviceIdEqualTo(deviceId)
        .and()
        .shopOpenDateEqualTo(date)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<List<Transaction>> getTodayTransactions(
      String deviceId, String date) async {
    final db = await isar;
    return await db.transactions
        .filter()
        .deviceIdEqualTo(deviceId)
        .and()
        .shopOpenDateEqualTo(date)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<Transaction?> getTransaction(String transactionId) async {
    final db = await isar;
    return await db.transactions
        .filter()
        .transactionIdEqualTo(transactionId)
        .findFirst();
  }

  Future<void> saveTransaction(Transaction transaction) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.transactions.put(transaction);
    });
  }

  Future<List<Transaction>> getUnsyncedTransactions(String deviceId) async {
    final db = await isar;
    return await db.transactions
        .filter()
        .deviceIdEqualTo(deviceId)
        .and()
        .isSyncedEqualTo(false)
        .findAll();
  }

  Future<void> markTransactionsSynced(List<String> transactionIds) async {
    final db = await isar;
    await db.writeTxn(() async {
      for (final txnId in transactionIds) {
        final txn = await db.transactions
            .filter()
            .transactionIdEqualTo(txnId)
            .findFirst();
        if (txn != null) {
          txn.isSynced = true;
          txn.syncedAt = DateTime.now();
          await db.transactions.put(txn);
        }
      }
    });
  }

  // ==================== TRANSACTION LINE QUERIES ====================

  Future<List<TransactionLine>> getTransactionLines(
      String transactionId) async {
    final db = await isar;
    return await db.transactionLines
        .filter()
        .transactionIdEqualTo(transactionId)
        .sortByCreatedAt()
        .findAll();
  }

  Future<void> saveTransactionLine(TransactionLine line) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.transactionLines.put(line);
    });
  }

  Future<void> saveMultipleTransactionLines(
      List<TransactionLine> lines) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.transactionLines.putAll(lines);
    });
  }

  Future<void> deleteTransactionLine(int lineId) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.transactionLines.delete(lineId);
    });
  }

  // ==================== SYNC HISTORY QUERIES ====================

  Future<void> saveSyncHistory(SyncHistory history) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.syncHistorys.put(history);
    });
  }

  Future<List<SyncHistory>> getAllSyncHistory() async {
    final db = await isar;
    return await db.syncHistorys.where().sortByDateTimeDesc().findAll();
  }

  Future<List<SyncHistory>> getSyncHistoryByDevice(String deviceId) async {
    final db = await isar;
    return await db.syncHistorys
        .filter()
        .fromDeviceIdEqualTo(deviceId)
        .sortByDateTimeDesc()
        .findAll();
  }

  // ==================== PRICE HISTORY QUERIES ====================

  Future<void> savePriceHistory(PriceHistory history) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.priceHistorys.put(history);
    });
  }

  Future<List<PriceHistory>> getItemPriceHistory(String itemId) async {
    final db = await isar;
    return await db.priceHistorys
        .filter()
        .itemIdEqualTo(itemId)
        .sortByChangedAtDesc()
        .findAll();
  }

  // ==================== STATISTICS QUERIES ====================

/*   Future<double> getTotalInventoryValue(String shopId) async {
    final items = await getAllItems(shopId);
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  } 
  
   Future<double> getTodayTotalSales(String deviceId, String date) async {
    final transactions = await getTodayTransactions(deviceId, date);
    return transactions.fold(0.0, (sum, txn) => sum + txn.totalAmount);
  }
  
  */

  Future<double> getTotalInventoryValue(String shopId) async {
    final items = await getAllItems(shopId);
    double total = 0.0;
    for (final item in items) {
      total += (item.price * item.quantity);
    }
    return total;
  }

   Future<double> getTodayTotalSales(String deviceId, String date) async {
    final transactions = await getTodayTransactions(deviceId, date);
    double total = 0.0;
    for (final txn in transactions) {
      total += txn.totalAmount;
    }
    return total;
  }

  Future<Map<String, dynamic>> getInventoryStats(String shopId) async {
    final families = await getAllFamilies(shopId);
    final items = await getAllItems(shopId);
    final totalValue = await getTotalInventoryValue(shopId);
    final lowStockCount = await getLowStockCount(shopId);

    return {
      'totalFamilies': families.length,
      'totalItems': items.length,
      'totalValue': totalValue,
      'lowStockCount': lowStockCount,
    };
  }
}