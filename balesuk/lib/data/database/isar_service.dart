import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_models.dart';
import '../../core/helpers/id_generator.dart';

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
    final config =
        await db.deviceConfigs.filter().deviceIdEqualTo(deviceId).findFirst();

    if (config != null) {
      config.currentTrxCounter = newCounter;
      await db.writeTxn(() async {
        await db.deviceConfigs.put(config);
      });
    }
  }

  Future<void> resetTrxCounterForNewDay(String deviceId, String newDate) async {
    final db = await isar;
    final config =
        await db.deviceConfigs.filter().deviceIdEqualTo(deviceId).findFirst();

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

  // ==================== FAMILY QUERIES ====================

  Future<ItemFamily?> getFamilyByCode(int familyCode, String shopId) async {
    final db = await isar;

    return await db.itemFamilys
        .filter()
        .familyCodeEqualTo(familyCode) // ⭐ Integer comparison!
        .and()
        .shopIdEqualTo(shopId)
        .sortByCreatedAtDesc()
        .findFirst();
  }

  /// Get all families for a shop
  Future<List<ItemFamily>?> getAllFamilies(
      int pageSize, int offset, String shopId) async {
    final db = await isar;

    return await db.itemFamilys
        .filter()
        .shopIdEqualTo(shopId)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(pageSize)
        .findAll();
  }

  Future<ItemFamily?> searchFamily(String shopId, String familyName) async {
    final db = await isar;
    return await db.itemFamilys
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .nameEqualTo(familyName, caseSensitive: false)
        .findFirst();
  }

  Stream<List<ItemFamily>> watchAllFamilies(String shopId) async* {
    final db = await isar;
    yield* db.itemFamilys
        .filter()
        .shopIdEqualTo(shopId)
        .sortByName()
        .watch(fireImmediately: true);
  }

  Future<int> getFamilyCount(String shopId) async {
    final db = await isar;
    return await db.itemFamilys.filter().shopIdEqualTo(shopId).count();
  }

  Future<bool> exists(int familyCode, String shopId) async {
    final db = await isar;
    return await db.itemFamilys
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .familyCodeEqualTo(familyCode)
        .isEmpty();
  }

  Future<void> saveFamily(ItemFamily family) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.itemFamilys.put(family);
    });
  }

  Future<void> deleteFamilyByCode(int familyCode, String shopId) async {
    final db = await isar;
    await db.writeTxn(() async {
      final family = await db.itemFamilys
          .filter()
          .shopIdEqualTo(shopId)
          .and()
          .familyCodeEqualTo(familyCode)
          .findFirst();

      if (family != null) {
        await db.itemFamilys.delete(family.id);
      }
    });
  }

  Future<int> getNextFamilyCode(int familyDigits, String shopId) async {
    final db = await isar;

    // Get max family code
    final maxCode = await db.itemFamilys
        .filter()
        .shopIdEqualTo(shopId)
        .familyCodeProperty()
        .max();

    final int nextCode = (maxCode ?? 0) + 1;

    // Check capacity
    final maxCapacity = IdGenerator.calculateMaxCapacity(familyDigits);
    if (nextCode > maxCapacity) {
      throw Exception(
          'Shop has reached family capacity ($maxCapacity families). '
          'Cannot create more families.');
    }

    return nextCode;
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

  Future<bool> hasActiveItems(int familyCode) async {
    final db = await isar;
    final itemCount = await db.items
        .filter()
        .familyCodeEqualTo(familyCode)
        .and()
        .isDeletedEqualTo(false) // Exclude deleted
        .count();

    return itemCount > 0;
  }

  Future<int> getFamilyItemCount(int familyCode) async {
    final db = await isar;
    return await db.items
        .filter()
        .familyCodeEqualTo(familyCode)
        .and()
        .isDeletedEqualTo(false) // Exclude deleted
        .count();
  }

  Future<List<Item>> getItemsByFamilyCode(
      int familyCode, int pageSize, int offset, String shopId) async {
    final db = await isar;
    return await db.items
        .filter()
        .familyCodeEqualTo(familyCode)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .shopIdEqualTo(shopId)
        .sortByName()
        .offset(offset)
        .limit(pageSize)
        .findAll();
  }

  Future<Item?> getItemByBarcode(String barcode, String shopId) async {
    // Parse barcode to integer
    final itemCode = IdGenerator.parseBarcodeToItemCode(barcode);
    return getItemByCode(itemCode, shopId);
  }

  Future<Item?> getItemByCode(int itemCode, String shopId) async {
    final db = await isar;

    return await db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .itemCodeEqualTo(itemCode) // ⭐ Integer comparison!
        .and()
        .isDeletedEqualTo(false)
        .findFirst();
  }

  Future<void> saveItem(Item item) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.items.put(item);
    });
  }

  Future<void> saveItemWithAttributes(
      Item item, List<ItemAttribute> attributes) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.items.put(item);
      await db.itemAttributes.putAll(attributes);
    });
  }

  Future<void> saveMultipleItems(List<Item> items) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.items.putAll(items);
    });
  }

  Future<void> updateItemQuantity(int itemCode, int delta, String shopId) async {
    final db = await isar;
    final item = await getItemByCode(itemCode, shopId);

    if (item != null) {
      item.quantity += delta;
      item.updatedAt = DateTime.now();
      await db.writeTxn(() async {
        await db.items.put(item);
      });
    }
  }

  Future<List<Item>> searchItemsByName(
      String shopId, int page, int offset, String query) async {
    final db = await isar;

    // Text search - search by name
    return await db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .nameContains(query, caseSensitive: false)
        .offset(offset)
        .limit(page)
        .findAll();
  }

  Future<List<Item>> searchItemsByCodeRange({
    required String shopId,
    required int startCode,
    required int endCode,
  }) async {
    final db = await isar;

    return await db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .itemCodeBetween(startCode, endCode) // ⭐ Integer range!
        .sortByItemCode()
        .findAll();
  }

  Future<void> updateLastSoldDate(int itemCode, String shopId) async {
    final db = await isar;
    final item = await getItemByCode(itemCode, shopId);

    if (item != null) {
      await db.writeTxn(() async {
        item.lastSoldAt = DateTime.now();
        await db.items.put(item);
      });
    }
  }

  Future<int> getLowStockCount(String shopId, int quantityThreshold) async {
    final db = await isar;
    return db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .quantityLessThan(quantityThreshold)
        .count();
  }

  Future<List<Item>> getLowStockItems(
      String shopId, int quantityThreshold, int pageSize, int offset) async {
    final db = await isar;
    return db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .quantityLessThan(quantityThreshold)
        .offset(offset)
        .limit(pageSize)
        .findAll();
  }

  Future<int> getAllItemCount(String shopId) async {
    final db = await isar;
    return db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(false)
        .count();
  }

  Future<int> getActiveItemCount(String shopId) async {
    final db = await isar;
    return db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .isActiveEqualTo(true)
        .count();
  }

  Future<int> getOutOfStockCount(String shopId) async {
    final db = await isar;
    return db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .isActiveEqualTo(true)
        .and()
        .quantityEqualTo(0)
        .count();
  }

  Future<Map<String, dynamic>> getInventoryStats(
      String shopId, int quantityThreshold) async {
    return {
      'totalItems': getAllItemCount(shopId),
      'activeItems': getActiveItemCount(shopId),
      'lowStockItems': getLowStockCount(shopId, quantityThreshold),
      'outOfStockItems': getOutOfStockCount(shopId),
    };
  }

  Future<int> getNextItemCode({
    required int familyCode,
    required int itemDigits,
    required String shopId,
  }) async {
    final db = await isar;

    // 1. Check for soft-deleted items (reusable slots)
    final deletedItemCode = await db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .familyCodeEqualTo(familyCode) // ⭐ Fast integer comparison!
        .and()
        .isDeletedEqualTo(true)
        .itemCodeProperty()
        .findFirst();

    if (deletedItemCode != null) {
      final reuseCode = deletedItemCode;

      await db.writeTxn(() async {
        await db.items.deleteByItemCode(deletedItemCode);
      });

      print('INFO: Reusing soft-deleted code: $reuseCode');
      return reuseCode;
    }

    // 2. Get family to access tracked sequence
    final family = await db.itemFamilys
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .familyCodeEqualTo(familyCode) // ⭐ Fast integer comparison!
        .findFirst();

    if (family == null) {
      throw Exception('Family not found: $familyCode');
    }

    // 3. Increment sequence - O(1) operation! ⭐
    final nextSequence = family.currentMaxSequence + 1;

    // 4. Check capacity
    final maxCapacity = IdGenerator.calculateMaxCapacity(itemDigits);
    if (nextSequence > maxCapacity) {
      throw Exception('Family $familyCode has reached capacity ($maxCapacity). '
          'Expand to ${itemDigits + 1} digits.');
    }

    // 5. Warn if near capacity (80%)
    if (IdGenerator.isNearCapacity(nextSequence, itemDigits)) {
      print('WARNING: Family $familyCode is at 80% capacity');
    }

    // 6. Update family max sequence
    await db.writeTxn(() async {
      family.currentMaxSequence = nextSequence;
      await db.itemFamilys.put(family);
    });

    return nextSequence;
  }

  Future<List<Item>> getEligibleForSoftDelete(String shopId) async {
    final db = await isar;
    final allItems = await db.items.filter().shopIdEqualTo(shopId).findAll();

    return allItems.where((item) => item.canBeSoftDeleted).toList();
  }

  // ==================== ATTRIBUTE QUERIES ====================

  Future<List<AttributeDefinition>> getAttributesByFamilyCode(
      int familyCode) async {
    final db = await isar;

    return await db.attributeDefinitions
        .filter()
        .familyCodeEqualTo(familyCode) // ⭐ Integer comparison!
        .sortByDisplayOrder()
        .findAll();
  }

  Future<AttributeDefinition?> getAttributeDefinitionById(int id) async {
    final db = await isar;
    return await db.attributeDefinitions.get(id);
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

  Future<void> deleteAttributeDefinition(int attributeId) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.attributeDefinitions.delete(attributeId);
    });
  }

  Future<List<String>> getItemsWithAttribute(int attributeDefId) async {
    final db = await isar;
    final attributes = await db.itemAttributes
        .filter()
        .attributeDefinitionIdEqualTo(attributeDefId)
        .findAll();

    // Return unique item IDs
    return attributes.map((a) => a.itemId).toSet().toList();
  }

  Future<List<ItemAttribute>> getItemAttributesByCode(int itemCode) async {
    final db = await isar;

    return await db.itemAttributes
        .filter()
        .itemCodeEqualTo(itemCode) // ⭐ Integer comparison!
        .findAll();
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

  Future<void> deleteItemAttribute(int attributeId) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.itemAttributes.delete(attributeId);
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
        .limit(10)
        .watch(fireImmediately: true);
  }

  Future<int> countTodayTransactions(String deviceId, String date) async {
    final db = await isar;
    return await db.transactions
        .filter()
        .deviceIdEqualTo(deviceId)
        .and()
        .shopOpenDateEqualTo(date)
        .count();
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

  Future<List<Transaction>> getTransactionsByDateRange({
    required String shopId,
    required String startDate,
    required String endDate,
  }) async {
    final db = await isar;
    return await db.transactions
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .shopOpenDateBetween(startDate, endDate)
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

  Future<List<Transaction>> getUnsyncedTransactionsByShop(String shopId) async {
    final db = await isar;
    return await db.transactions
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isSyncedEqualTo(false)
        .sortByCreatedAtDesc()
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

  Future<List<Map<String, dynamic>>> getTransactionLinesWithItems(
      String transactionId) async {
    final db = await isar;

    final lines = await db.transactionLines
        .filter()
        .transactionIdEqualTo(transactionId)
        .sortByLineNumber()
        .findAll();

    // Enrich with current item data (if still exists)
    final enrichedLines = <Map<String, dynamic>>[];

    for (final line in lines) {
      final item = await db.items
          .filter()
          .itemCodeEqualTo(line.itemCode) // ⭐ Integer comparison!
          .findFirst();

      enrichedLines.add({
        'line': line,
        'item': item, // May be null if item deleted
        'itemId': line.itemId, // Formatted string from line
        'itemName': line.itemName ?? item?.name ?? 'Unknown',
      });
    }

    return enrichedLines;
  }

  Future<void> saveTransactionLine(TransactionLine line) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.transactionLines.put(line);
    });
  }

  Future<void> saveMultipleTransactionLines(List<TransactionLine> lines) async {
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

  Future<void> savePriceHistory({required PriceHistory history}) async {
    final db = await isar;

    await db.writeTxn(() async {
      await db.priceHistorys.put(history);
    });
  }

  Future<void> updateItemAndSaveHistory(
      {required item, required history}) async {
    final db = await isar;

    await db.writeTxn(() async {
      await db.items.put(item);
      await db.priceHistorys.put(history);
    });
  }

  /// Get price history for an item
  Future<List<PriceHistory>> getPriceHistoryByCode(int itemCode) async {
    final db = await isar;

    return await db.priceHistorys
        .filter()
        .itemCodeEqualTo(itemCode) // ⭐ Integer comparison!
        .sortByChangedAtDesc()
        .findAll();
  }

  // ==================== SOFT DELETE OPERATIONS ====================

  Future<void> softDeleteItem(int itemCode, String shopId) async {
    final db = await isar;

    final item = await db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .itemCodeEqualTo(itemCode) // ⭐ Integer comparison!
        .findFirst();

    if (item == null) {
      throw Exception('Item not found: $itemCode');
    }

    if (!item.canBeSoftDeleted) {
      throw Exception('Item cannot be deleted (still has stock or is active)');
    }

    await db.writeTxn(() async {
      item.isDeleted = true;
      item.deletedAt = DateTime.now();
      item.isActive = false;
      await db.items.put(item);
    });

    print('INFO: Item soft deleted - Code: $itemCode, Name: ${item.name}');
  }

  /// Get all soft-deleted items
  Future<List<Item>> getSoftDeletedItems(String shopId) async {
    final db = await isar;

    return await db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(true)
        .sortByDeletedAt()
        .findAll();
  }

  /// Get count of soft-deleted items
  Future<int> getSoftDeletedCount(String shopId) async {
    final db = await isar;

    return await db.items
        .filter()
        .shopIdEqualTo(shopId)
        .and()
        .isDeletedEqualTo(true)
        .count();
  }

  Future<int> getNextSequence(String key, String shopId) async {
    final db = await isar;

    // Get max sequence value
    await db.writeTxn(() async {
      // 1. Get the current sequence record.
      // We use the composite index (key + shopId) to find the unique record.
      Sequence? sequence = await db.sequences
          .filter()
          .keyEqualTo(key)
          .shopIdEqualTo(shopId)
          .findFirst();

      if (sequence == null) {
        // 2. If it doesn't exist, create it starting at 1.
        sequence = Sequence(key: key.hashCode, shopId: shopId, value: 1);
      } else {
        // 3. If it exists, increment the value.
        sequence.value++;
      }

      // 4. Save the updated/new sequence record.
      await db.sequences.put(sequence);
      return sequence.value;
    });
  }

  Future<List<int>> getNextSequences(
    String sequenceKey,
    String shopId,
    int count,
  ) async {
    final isarInstance = await isar;

    // Use Isar's write transaction to guarantee atomicity.
    final sequenceList = await isarInstance.writeTxn(() async {
      // 1. Search for the unique sequence record.
      Sequence? sequence = await isarInstance.sequences
          .filter()
          .keyEqualTo(sequenceKey.hashCode)
          .shopIdEqualTo(shopId)
          .findFirst();

      int startValue;
      if (sequence == null) {
        // 2. If no record found, start the sequence at 1.
        startValue = 1;
        sequence =
            Sequence(key: sequenceKey.hashCode, shopId: shopId, value: count);
      } else {
        // 3. If record exists, the next sequence starts after the current value.
        startValue = sequence.value + 1;
        sequence.value += count; // Increment the value by the requested count
      }

      // 4. Save the updated sequence record.
      await isarInstance.sequences.put(sequence);

      // 5. Generate the list of reserved sequences: [startValue, startValue + 1, ..., sequence.value]
      return List<int>.generate(count, (i) => startValue + i);
    });

    return sequenceList;
  }
// ----------------- isar_service.dart -----------------

  Future<T> runInTransaction<T>(
      Future<T> Function() transactionCallback) async {
    final isar = await this.isar;

    // No try/catch here! Let exceptions bubble up.
    T? result;
    await isar.writeTxn(() async {
      // Execute the logic provided by the repository
      result = await transactionCallback();
    });

    // Return the result directly, relying on the transaction wrapper to handle atomicity
    if (result == null) {
      throw Exception('Isar transaction failed to return an object.');
    }
    return result!;
  }
}
