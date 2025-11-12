import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/money.dart';
import '../../core/utils/result.dart';
import '../../core/helpers/id_generator.dart';
import '../database/isar_service.dart';
import '../models/isar_models.dart';

// ==================== DATABASE PROVIDER ====================

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService.instance;
});

// ==================== DTOs ====================

class CreateFamilyDto {
  final String shopId;
  final String name;
  final String? description;
  final int familyDigits;

  CreateFamilyDto({
    required this.shopId,
    required this.name,
    this.description,
    required this.familyDigits,
  });
}

class CreateItemDto {
  final String familyId;
  final String shopId;
  final String name;
  final Money price;
  final int quantity;
  final int minQuantity;
  final int familyDigits;
  final int itemDigits;
  final Map<int, dynamic>? attributeValues;

  CreateItemDto({
    required this.familyId,
    required this.shopId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.minQuantity,
    required this.familyDigits,
    required this.itemDigits,
    this.attributeValues,
  });
}

class UpdateItemDto {
  final String? name;
  final Money? price;
  final int? quantity;
  final int? minQuantity;
  final bool? isActive;

  UpdateItemDto({
    this.name,
    this.price,
    this.quantity,
    this.minQuantity,
    this.isActive,
  });

  bool get hasUpdates =>
      name != null ||
      price != null ||
      quantity != null ||
      minQuantity != null ||
      isActive != null;
}

class BulkCreateItemsDto {
  final String familyId;
  final String shopId;
  final List<ItemData> items;
  final int familyDigits;
  final int itemDigits;

  BulkCreateItemsDto({
    required this.familyId,
    required this.shopId,
    required this.items,
    required this.familyDigits,
    required this.itemDigits,
  });
}

class ItemData {
  final String name;
  final Money price;
  final int quantity;
  final int minQuantity;

  ItemData({
    required this.name,
    required this.price,
    required this.quantity,
    required this.minQuantity,
  });
}

// ==================== INVENTORY REPOSITORY ====================

class InventoryRepository with LoggerMixin {
  final IsarService _isarService;

  InventoryRepository(this._isarService);

  // ==================== FAMILY OPERATIONS ====================

  /// Get all families for a shop
  Future<Result<List<ItemFamily>>> getFamiliesByShop(String shopId) async {
    try {
      logInfo('Fetching families for shop: $shopId');
      final families = await _isarService.getAllFamilies(shopId);
      logSuccess('Fetched ${families.length} families');
      return Success(families);
    } catch (e, stack) {
      logError('Failed to fetch families', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load families', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get family by ID
  Future<Result<ItemFamily>> getFamilyById(String familyId) async {
    try {
      final family = await _isarService.getFamilyById(familyId);
      if (family == null) {
        return Error(NotFoundFailure('Family not found: $familyId'));
      }
      return Success(family);
    } catch (e, stack) {
      logError('Failed to fetch family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load family', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Create a new family
  Future<Result<ItemFamily>> createFamily(CreateFamilyDto dto) async {
    try {
      // Validation
      if (dto.name.trim().isEmpty) {
        return Error(ValidationFailure('Family name is required'));
      }

      if (dto.name.length > 100) {
        return Error(ValidationFailure('Family name must be 100 characters or less'));
      }

      logInfo('Creating family: ${dto.name}');

      // Check for duplicate name
      final existingFamilies = await _isarService.getAllFamilies(dto.shopId);
      final duplicate = existingFamilies.any(
        (f) => f.name.toLowerCase() == dto.name.toLowerCase(),
      );

      if (duplicate) {
        return Error(DuplicateFailure('Family with name "${dto.name}" already exists'));
      }

      // Generate family ID
      final sequence = await _isarService.getNextFamilySequence(dto.shopId);
      final familyId = IdGenerator.generateFamilyId(
        sequence: sequence,
        digits: dto.familyDigits,
      );

      // Create family
      final family = ItemFamily.create(
        familyId: familyId,
        shopId: dto.shopId,
        name: dto.name.trim(),
        description: dto.description?.trim(),
        createdAt: DateTime.now(),
      );

      await _isarService.saveFamily(family);

      logSuccess('Family created: $familyId - ${dto.name}');
      AppLogger.inventory('Family created', details: 'ID: $familyId, Name: ${dto.name}');

      return Success(family);
    } catch (e, stack) {
      logError('Failed to create family', error: e, stackTrace: stack);
      AppLogger.error('Failed to create family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to create family', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Delete a family
  Future<Result<void>> deleteFamily(String familyId) async {
    try {
      logInfo('Deleting family: $familyId');

      // Check if family has items
      final items = await _isarService.getItemsByFamily(familyId);
      if (items.isNotEmpty) {
        return Error(BusinessRuleFailure('Cannot delete family with ${items.length} items. Delete items first.'));
      }

      await _isarService.deleteFamily(familyId);

      logSuccess('Family deleted: $familyId');
      AppLogger.inventory('Family deleted', details: 'ID: $familyId');

      return const Success(null);
    } catch (e, stack) {
      logError('Failed to delete family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to delete family', exception: e as Exception?, stackTrace: stack));
    }
  }

  // ==================== ITEM OPERATIONS ====================

  /// Get all items for a shop
  Future<Result<List<Item>>> getItemsByShop(String shopId) async {
    try {
      final items = await _isarService.getAllItems(shopId);
      return Success(items);
    } catch (e, stack) {
      logError('Failed to fetch items', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load items', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get items by family
  Future<Result<List<Item>>> getItemsByFamily(String familyId) async {
    try {
      final items = await _isarService.getItemsByFamily(familyId);
      return Success(items);
    } catch (e, stack) {
      logError('Failed to fetch items by family', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load items', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get item by ID
  Future<Result<Item>> getItemById(String itemId) async {
    try {
      final item = await _isarService.getItemById(itemId);
      if (item == null) {
        return Error(NotFoundFailure('Item not found: $itemId'));
      }
      return Success(item);
    } catch (e, stack) {
      logError('Failed to fetch item', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to load item', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Search items
  Future<Result<List<Item>>> searchItems(String shopId, String query) async {
    try {
      if (query.trim().isEmpty) {
        return await getItemsByShop(shopId);
      }

      final items = await _isarService.searchItems(shopId, query);
      return Success(items);
    } catch (e, stack) {
      logError('Failed to search items', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to search items', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Create a new item
  Future<Result<Item>> createItem(CreateItemDto dto) async {
    try {
      // Validation
      if (dto.name.trim().isEmpty) {
        return const Error(ValidationFailure('Item name is required'));
      }

      if (dto.name.length > 200) {
        return const Error(ValidationFailure('Item name must be 200 characters or less'));
      }

      if (dto.price.amount <= 0) {
        return const Error(ValidationFailure('Price must be greater than zero'));
      }

      if (dto.quantity < 0) {
        return const Error(ValidationFailure('Quantity cannot be negative'));
      }

      if (dto.minQuantity < 0) {
        return const Error(ValidationFailure('Minimum quantity cannot be negative'));
      }

      logInfo('Creating item: ${dto.name} in family: ${dto.familyId}');

      // Verify family exists
      final family = await _isarService.getFamilyById(dto.familyId);
      if (family == null) {
        return Error(NotFoundFailure('Family not found: ${dto.familyId}'));
      }

      // Generate item ID
      final sequence = await _isarService.getNextItemSequence(dto.familyId, dto.itemDigits);
      final itemId = IdGenerator.generateItemId(
        familyId: dto.familyId,
        itemSequence: sequence,
        familyDigits: dto.familyDigits,
        itemDigits: dto.itemDigits,
      );

      // Create item
      final item = Item.create(
        itemId: itemId,
        familyId: dto.familyId,
        shopId: dto.shopId,
        name: dto.name.trim(),
        priceValue: dto.price,
        quantity: dto.quantity,
        minQuantity: dto.minQuantity,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _isarService.saveItem(item);

      // Save attributes if provided
      if (dto.attributeValues != null && dto.attributeValues!.isNotEmpty) {
        final attributes = <ItemAttribute>[];

        for (final entry in dto.attributeValues!.entries) {
          final attributeId = entry.key;
          final value = entry.value;

          String? valueText;
          double? valueNumber;
          String? valueDate;
          bool? valueBoolean;

          if (value is String) {
            valueText = value;
          } else if (value is num) {
            valueNumber = value.toDouble();
          } else if (value is bool) {
            valueBoolean = value;
          } else if (value is DateTime) {
            valueDate = value.toIso8601String().substring(0, 10);
          }

          attributes.add(ItemAttribute.create(
            itemId: itemId,
            attributeDefinitionId: attributeId,
            valueText: valueText,
            valueNumber: valueNumber,
            valueDate: valueDate,
            valueBoolean: valueBoolean,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }

        await _isarService.saveMultipleItemAttributes(attributes);
      }

      logSuccess('Item created: $itemId - ${dto.name}');
      AppLogger.inventory(
        'Item created',
        details: 'ID: $itemId, Name: ${dto.name}, Price: ${dto.price.format()}, Qty: ${dto.quantity}',
      );

      return Success(item);
    } catch (e, stack) {
      logError('Failed to create item', error: e, stackTrace: stack);
      AppLogger.error('Failed to create item', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to create item', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Bulk create items
  Future<Result<List<Item>>> bulkCreateItems(BulkCreateItemsDto dto) async {
    try {
      if (dto.items.isEmpty) {
        return Error(ValidationFailure('No items to create'));
      }

      logInfo('Bulk creating ${dto.items.length} items');

      // Verify family exists
      final family = await _isarService.getFamilyById(dto.familyId);
      if (family == null) {
        return Error(NotFoundFailure('Family not found: ${dto.familyId}'));
      }

      final items = <Item>[];
      int sequence = await _isarService.getNextItemSequence(dto.familyId, dto.itemDigits);

      for (final itemData in dto.items) {
        // Validate each item
        if (itemData.name.trim().isEmpty) {
          return Error(ValidationFailure('All items must have a name'));
        }

        if (itemData.price.amount <= 0) {
          return Error(ValidationFailure('All items must have a price greater than zero'));
        }

        final itemId = IdGenerator.generateItemId(
          familyId: dto.familyId,
          itemSequence: sequence,
          familyDigits: dto.familyDigits,
          itemDigits: dto.itemDigits,
        );

        items.add(Item.create(
          itemId: itemId,
          familyId: dto.familyId,
          shopId: dto.shopId,
          name: itemData.name.trim(),
          priceValue: itemData.price,
          quantity: itemData.quantity,
          minQuantity: itemData.minQuantity,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        sequence++;
      }

      await _isarService.saveMultipleItems(items);

      logSuccess('Bulk created ${items.length} items');
      AppLogger.inventory('Bulk items created', details: 'Count: ${items.length}');

      return Success(items);
    } catch (e, stack) {
      logError('Failed to bulk create items', error: e, stackTrace: stack);
      AppLogger.error('Failed to bulk create items', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to bulk create items', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Update an item
  Future<Result<Item>> updateItem(String itemId, UpdateItemDto dto) async {
    try {
      if (!dto.hasUpdates) {
        return Error(ValidationFailure('No updates provided'));
      }

      logInfo('Updating item: $itemId');

      // Get existing item
      final itemResult = await getItemById(itemId);
      if (itemResult.isError) {
        return Error(itemResult.failureOrNull!);
      }

      final item = itemResult.dataOrNull!;

      // Validate updates
      if (dto.name != null && dto.name!.trim().isEmpty) {
        return Error(ValidationFailure('Item name cannot be empty'));
      }

      if (dto.price != null && dto.price!.amount <= 0) {
        return Error(ValidationFailure('Price must be greater than zero'));
      }

      if (dto.quantity != null && dto.quantity! < 0) {
        return Error(ValidationFailure('Quantity cannot be negative'));
      }

      if (dto.minQuantity != null && dto.minQuantity! < 0) {
        return Error(ValidationFailure('Minimum quantity cannot be negative'));
      }

      // Apply updates
      if (dto.name != null) item.name = dto.name!.trim();
      if (dto.quantity != null) item.quantity = dto.quantity!;
      if (dto.minQuantity != null) item.minQuantity = dto.minQuantity!;
      if (dto.isActive != null) item.isActive = dto.isActive!;

      // Handle price change with history
      if (dto.price != null && item.price != dto.price!.amount) {
        final oldPrice = item.priceAsMoney;
        await _isarService.savePriceHistory(
          PriceHistory.create(
            itemId: itemId,
            oldPriceValue: oldPrice,
            newPriceValue: dto.price!,
            changedAt: DateTime.now(),
            changedBy: item.shopId, // TODO: Use actual user/device ID
          ),
        );
        item.priceAsMoney = dto.price!;
      }

      item.updatedAt = DateTime.now();
      await _isarService.saveItem(item);

      logSuccess('Item updated: $itemId');
      AppLogger.inventory('Item updated', details: 'ID: $itemId');

      return Success(item);
    } catch (e, stack) {
      logError('Failed to update item', error: e, stackTrace: stack);
      AppLogger.error('Failed to update item', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to update item', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Adjust item quantity
  Future<Result<Item>> adjustQuantity({
    required String itemId,
    required int adjustment,
    String? reason,
  }) async {
    try {
      final itemResult = await getItemById(itemId);
      if (itemResult.isError) {
        return Error(itemResult.failureOrNull!);
      }

      final item = itemResult.dataOrNull!;
      final newQuantity = item.quantity + adjustment;

      if (newQuantity < 0) {
        return Error(BusinessRuleFailure('Adjustment would result in negative quantity'));
      }

      item.quantity = newQuantity;
      item.updatedAt = DateTime.now();
      await _isarService.saveItem(item);

      logInfo('Adjusted quantity for ${item.itemId}: $adjustment (reason: ${reason ?? 'none'})');
      AppLogger.inventory(
        'Quantity adjusted',
        details: 'Item: ${item.itemId}, Adjustment: $adjustment, New: $newQuantity',
      );

      return Success(item);
    } catch (e, stack) {
      logError('Failed to adjust quantity', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to adjust quantity', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Delete item (soft delete)
  Future<Result<void>> deleteItem(String itemId) async {
    try {
      logInfo('Deleting item: $itemId');

      final itemResult = await getItemById(itemId);
      if (itemResult.isError) {
        return Error(itemResult.failureOrNull!);
      }

      final item = itemResult.dataOrNull!;

      // Soft delete
      item.isActive = false;
      item.updatedAt = DateTime.now();
      await _isarService.saveItem(item);

      logSuccess('Item deleted: $itemId');
      AppLogger.inventory('Item deleted', details: 'ID: $itemId');

      return const Success(null);
    } catch (e, stack) {
      logError('Failed to delete item', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to delete item', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get low stock items
  Future<Result<List<Item>>> getLowStockItems(String shopId) async {
    try {
      final allItemsResult = await getItemsByShop(shopId);
      if (allItemsResult.isError) {
        return Error(allItemsResult.failureOrNull!);
      }

      final items = allItemsResult.dataOrNull!
          .where((item) => item.isActive && item.quantity <= item.minQuantity)
          .toList();

      return Success(items);
    } catch (e, stack) {
      logError('Failed to get low stock items', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to get low stock items', exception: e as Exception?, stackTrace: stack));
    }
  }

  /// Get inventory statistics
  Future<Result<Map<String, int>>> getInventoryStats(String shopId) async {
    try {
      final itemsResult = await getItemsByShop(shopId);
      if (itemsResult.isError) {
        return Error(itemsResult.failureOrNull!);
      }

      final items = itemsResult.dataOrNull!;
      final stats = <String, int>{
        'totalItems': items.length,
        'activeItems': items.where((i) => i.isActive).length,
        'lowStockItems': items.where((i) => i.isActive && i.quantity <= i.minQuantity).length,
        'outOfStockItems': items.where((i) => i.isActive && i.quantity == 0).length,
      };

      return Success(stats);
    } catch (e, stack) {
      logError('Failed to get inventory stats', error: e, stackTrace: stack);
      return Error(DatabaseFailure('Failed to get inventory stats', exception: e as Exception?, stackTrace: stack));
    }
  }
}

// ==================== REPOSITORY PROVIDER ====================

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return InventoryRepository(isarService);
});