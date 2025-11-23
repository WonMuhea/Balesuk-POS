
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/result.dart';
import '../database/isar_service.dart';
import '../models/isar_models.dart';

// ==================== DATABASE PROVIDER ====================

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService.instance;
});

// ==================== INVENTORY REPOSITORY ====================

class InventoryRepository with LoggerMixin {
  final IsarService _isarService;

  InventoryRepository(this._isarService);

  // ==================== FAMILY OPERATIONS ====================

  Future<Result<int>> getItemFamilyCount(String shopId) async {
    try {
      logInfo('Fetching families count for shop');
      final count = await _isarService.getFamilyCount(shopId);
      logSuccess('Fetched $count families');
      return Success(count);
    } catch (e, stack) {
      logError('Failed to fetch families', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load families',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  Future<Result<List<ItemFamily>?>> fetchItemFamilies(int page, int offset, String shopId) async {
    try {
      logInfo('Fetching all families for shop');
      final families = await _isarService.getAllFamilies(page, offset,shopId);
      logSuccess('Fetched ${families?.length} families');
      return Success(families);
    } catch (e, stack) {
      logError('Failed to fetch families', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load families',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  Future<Result<bool>> familyExists(int familyCode, String shopId) async {
    try {
      final boolRes = await _isarService.exists(familyCode, shopId);
      return Success(boolRes);
    } catch (e, stack) {
      logError('Failed to fetch families', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load families',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get family by ID
  Future<Result<ItemFamily?>> getFamilyById(int familyCode, String shopId) async {
    try {
      final family = await _isarService.getFamilyByCode(familyCode, shopId);
      return Success(family);
    } catch (e, stack) {
      logError('Failed to fetch family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load family',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Create a new family
  Future<Result<ItemFamily>> createFamily(ItemFamily family) async {
    try {
      await _isarService.saveFamily(family);
      return Success(family);
    } catch (e, stack) {
      logError('Failed to create family', error: e, stackTrace: stack);
      AppLogger.error('Failed to create family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to create family',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  Future<Result<ItemFamily?>> searchFamilyByName(
      String shopId, String name) async {
    try {
      final family = await _isarService.searchFamily(shopId, name);
      return Success(family);
    } catch (e, stack) {
      logError('Failed to search family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to search family',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Delete a family
  Future<Result<void>> deleteFamily(int familyCode, String shopId) async {
    try {
      logInfo('Deleting family: $familyCode');

      // Check if family has items
      await _isarService.deleteFamilyByCode(familyCode, shopId);

      logSuccess('Family deleted: $familyCode');
      AppLogger.inventory('Family deleted', details: 'ID: $familyCode');

      return const Success(null);
    } catch (e, stack) {
      logError('Failed to delete family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to delete family',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  // ==================== ITEM OPERATIONS ====================

  /// Get items by family
  Future<Result<List<Item>?>> getItemsByFamily(
      int familyCode, int pageSize, int offset, String shopId) async {
    try {
      final items = await _isarService.getItemsByFamilyCode(
          familyCode, pageSize, offset, shopId);
      return Success(items);
    } catch (e, stack) {
      logError('Failed to fetch items by family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load items',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get item by ID
  Future<Result<Item?>> getItemById(int itemCode, String shopId) async {
    try {
      final item = await _isarService.getItemByCode(itemCode, shopId);
      return Success(item);
    } catch (e, stack) {
      logError('Failed to fetch item', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load item',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Search items
  Future<Result<List<Item>?>> searchItemsByName(String query, int page, int offset, String shopId) async {
    try {
      final items = await _isarService.searchItemsByName(query, page, offset, shopId);
      return Success(items);
    } catch (e, stack) {
      logError('Failed to search items', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to search items',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Create a new item
  Future<Result<Item>> saveItemWihtAttributes(
      Item item, List<ItemAttribute> attributes) async {
    try {
      await _isarService.saveItemWithAttributes(item, attributes);
      logSuccess('Item created: ${item.itemCode} - ${item.name}');
      AppLogger.inventory(
        'Item created',
        details:
            'ID: ${item.itemCode}, Name: ${item.name}, Price: ${item.price}, Qty: ${item.quantity}',
      );
      return Success(item);
    } catch (e, stack) {
      logError('Failed to create item', error: e, stackTrace: stack);
      AppLogger.error('Failed to create item', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to create item',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  Future<Result<Item>> saveItem(Item item) async {
    try {
      await _isarService.saveItem(item);
      logSuccess('Item created: ${item.itemCode} - ${item.name}');
      AppLogger.inventory(
        'Item created',
        details:
            'ID: ${item.itemCode}, Name: ${item.name}, Price: ${item.price}, Qty: ${item.quantity}',
      );
      return Success(item);
    } catch (e, stack) {
      logError('Failed to create item', error: e, stackTrace: stack);
      AppLogger.error('Failed to create item', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to create item',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  Future<Result<Item>> updateItemAndSaveHistory(
    Item updatedItem,
    PriceHistory priceHistory,
  ) async {
    try {
      // Delegate the atomic operation to the IsarService
      await _isarService.updateItemAndSaveHistory(
        item: updatedItem,
        history: priceHistory,
      );
      return Success(updatedItem);
    } catch (e, stack) {
      final errorMessage =
          'Failed to update item ${updatedItem.itemCode} and save price history.';
      AppLogger.error(errorMessage, error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        errorMessage,
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  Future<Result<void>> savePriceHistory(PriceHistory history) async {
    try {
      await _isarService.savePriceHistory(history: history);
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to save item price history',
          error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to save item price history',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Bulk create items
  Future<Result<List<Item>>> bulkCreateItems(List<Item> items) async {
    try {
      logInfo('Bulk creating ${items.length} items');

      // Verify family exists

      await _isarService.saveMultipleItems(items);

      logSuccess('Bulk created ${items.length} items');
      AppLogger.inventory('Bulk items created',
          details: 'Count: ${items.length}');

      return Success(items);
    } catch (e, stack) {
      logError('Failed to bulk create items', error: e, stackTrace: stack);
      AppLogger.error('Failed to bulk create items',
          error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to bulk create items',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Delete item (soft delete)
  Future<Result<void>> deleteItem(int itemCode, String shopId) async {
    try {
      await _isarService.softDeleteItem(itemCode, shopId);
      return const Success(null);
    } catch (e, stack) {
      return Error(DatabaseFailure('Failed to delete item',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get low stock items
  Future<Result<List<Item>>> getLowStockItems(
      String shopId, int quantityThreshold, int pageSize, int offset) async {
    try {
      final items = await _isarService.getLowStockItems(
          shopId, quantityThreshold, pageSize, offset);
      return Success(items);
    } catch (e, stack) {
      logError('Failed to get low stock items', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to get low stock items',
          exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get inventory statistics
  Future<Result<Map<String, int>>> getInventoryStats(
      String shopId, int quantityThreshold) async {
    try {
      final stats =
          await _isarService.getInventoryStats(shopId, quantityThreshold);
      final statsMap = stats.map(
        (key, value) {
          int intValue;

          if (value is int) {
            intValue = value;
          } else if (value is String) {
            // Use int.tryParse for safe String conversion
            intValue = int.tryParse(value) ?? 0;
          } else if (value is double) {
            // Convert double to int
            intValue = value.toInt();
          } else {
            // Default for null or any other type
            intValue = 0;
          }

          return MapEntry(key, intValue);
        },
      );

      return Success(statsMap);
    } catch (e, stack) {
      logError('Failed to get inventory stats', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to get inventory stats',
          exception: e as Exception?, stackTrace: stack));
    }
  }
}

// ==================== REPOSITORY PROVIDER ====================

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return InventoryRepository(isarService);
});
