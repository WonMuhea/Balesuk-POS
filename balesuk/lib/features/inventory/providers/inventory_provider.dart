import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/isar_service.dart';
import '../../../data/models/isar_models.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/money.dart';
import '../../../core/helpers/id_generator.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/providers/providers.dart';

// ==================== INVENTORY STATE ====================

class InventoryState {
  final List<ItemFamily> families;
  final List<Item> items;
  final String? selectedFamilyId;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  InventoryState({
    this.families = const [],
    this.items = const [],
    this.selectedFamilyId,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  InventoryState copyWith({
    List<ItemFamily>? families,
    List<Item>? items,
    String? selectedFamilyId,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return InventoryState(
      families: families ?? this.families,
      items: items ?? this.items,
      selectedFamilyId: selectedFamilyId ?? this.selectedFamilyId,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ==================== INVENTORY NOTIFIER ====================

class InventoryNotifier extends StateNotifier<InventoryState> with LoggerMixin {
  final IsarService _isarService;
  final String _shopId;

  InventoryNotifier(this._isarService, this._shopId) : super(InventoryState()) {
    loadFamilies();
  }

  // ==================== LOAD DATA ====================

  Future<void> loadFamilies() async {
    try {
      logInfo('Loading families for shop: $_shopId');
      state = state.copyWith(isLoading: true, errorMessage: null);

      final families = await _isarService.getAllFamilies(_shopId);
      
      logSuccess('Loaded ${families.length} families');
      state = state.copyWith(
        families: families,
        isLoading: false,
      );
    } catch (e, stack) {
      logError('Failed to load families', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.errorGeneric,
      );
    }
  }

  Future<void> loadItems({String? familyId}) async {
    try {
      logInfo('Loading items for family: ${familyId ?? 'all'}');
      state = state.copyWith(isLoading: true, errorMessage: null);

      final items = familyId != null
          ? await _isarService.getItemsByFamily(familyId)
          : await _isarService.getAllItems(_shopId);

      logSuccess('Loaded ${items.length} items');
      state = state.copyWith(
        items: items,
        selectedFamilyId: familyId,
        isLoading: false,
      );
    } catch (e, stack) {
      logError('Failed to load items', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.errorGeneric,
      );
    }
  }

  // ==================== SEARCH ====================

  Future<void> searchItems(String query) async {
    try {
      logInfo('Searching items: $query');
      state = state.copyWith(searchQuery: query, isLoading: true);

      if (query.isEmpty) {
        await loadItems();
        return;
      }

      final items = await _isarService.searchItems(_shopId, query);
      
      logInfo('Found ${items.length} items');
      state = state.copyWith(
        items: items,
        isLoading: false,
      );
    } catch (e, stack) {
      logError('Search failed', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.errorGeneric,
      );
    }
  }

  // ==================== CREATE FAMILY ====================

  Future<String?> createFamily({
    required String name,
    String? description,
    required int familyDigits,
  }) async {
    try {
      logInfo('Creating family: $name');

      // Generate family ID
      final sequence = await _isarService.getNextFamilySequence(_shopId);
      final familyId = IdGenerator.generateFamilyId(
        sequence: sequence,
        digits: familyDigits,
      );

      final family = ItemFamily.create(
        familyId: familyId,
        shopId: _shopId,
        name: name,
        description: description,
        createdAt: DateTime.now(),
      );

      await _isarService.saveFamily(family);
      
      logSuccess('Family created: $familyId');
      AppLogger.inventory('Family created', details: 'ID: $familyId, Name: $name');

      // Reload families
      await loadFamilies();

      return null; // No error
    } catch (e, stack) {
      logError('Failed to create family', error: e, stackTrace: stack);
      return AppStrings.errorGeneric;
    }
  }

  // ==================== CREATE ITEM ====================

  Future<String?> createItem({
    required String familyId,
    required String name,
    required Money price,
    required int quantity,
    required int minQuantity,
    required int familyDigits,
    required int itemDigits,
    Map<int, dynamic>? attributeValues,
  }) async {
    try {
      logInfo('Creating item: $name in family: $familyId');

      // Generate item ID
      final sequence = await _isarService.getNextItemSequence(familyId, itemDigits);
      final itemId = IdGenerator.generateItemId(
        familyId: familyId,
        itemSequence: sequence,
        familyDigits: familyDigits,
        itemDigits: itemDigits,
      );

      final item = Item.create(
        itemId: itemId,
        familyId: familyId,
        shopId: _shopId,
        name: name,
        priceValue: price,
        quantity: quantity,
        minQuantity: minQuantity,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _isarService.saveItem(item);

      // Save attributes if provided
      if (attributeValues != null && attributeValues.isNotEmpty) {
        final attributes = <ItemAttribute>[];
        
        for (final entry in attributeValues.entries) {
          final attributeId = entry.key;
          final value = entry.value;
          
          // Determine which field to set based on value type
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

      logSuccess('Item created: $itemId');
      AppLogger.inventory(
        'Item created',
        details: 'ID: $itemId, Name: $name, Price: ${price.format()}, Qty: $quantity',
      );

      // Reload items
      await loadItems(familyId: familyId);

      return null; // No error
    } catch (e, stack) {
      logError('Failed to create item', error: e, stackTrace: stack);
      return AppStrings.errorGeneric;
    }
  }

  // ==================== BULK CREATE ITEMS ====================

  Future<String?> bulkCreateItems({
    required String familyId,
    required List<Map<String, dynamic>> itemsData,
    required int familyDigits,
    required int itemDigits,
  }) async {
    try {
      logInfo('Bulk creating ${itemsData.length} items');

      final items = <Item>[];
      int sequence = await _isarService.getNextItemSequence(familyId, itemDigits);

      for (final itemData in itemsData) {
        final itemId = IdGenerator.generateItemId(
          familyId: familyId,
          itemSequence: sequence,
          familyDigits: familyDigits,
          itemDigits: itemDigits,
        );

        items.add(Item.create(
          itemId: itemId,
          familyId: familyId,
          shopId: _shopId,
          name: itemData['name'] as String,
          priceValue: itemData['price'] as Money,
          quantity: itemData['quantity'] as int,
          minQuantity: itemData['minQuantity'] as int,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        sequence++;
      }

      await _isarService.saveMultipleItems(items);

      logSuccess('Bulk created ${items.length} items');
      AppLogger.inventory('Bulk items created', details: 'Count: ${items.length}');

      // Reload items
      await loadItems(familyId: familyId);

      return null; // No error
    } catch (e, stack) {
      logError('Failed to bulk create items', error: e, stackTrace: stack);
      return AppStrings.errorGeneric;
    }
  }

  // ==================== UPDATE ITEM ====================

  Future<String?> updateItem({
    required Item item,
    String? name,
    Money? price,
    int? quantity,
    int? minQuantity,
    bool? isActive,
  }) async {
    try {
      logInfo('Updating item: ${item.itemId}');

      if (name != null) item.name = name;
      if (quantity != null) item.quantity = quantity;
      if (minQuantity != null) item.minQuantity = minQuantity;
      if (isActive != null) item.isActive = isActive;
      
      if (price != null && item.price != price.amount) {
        // Log price change
        final oldPrice = item.priceAsMoney;
        await _isarService.savePriceHistory(
          PriceHistory.create(
            itemId: item.itemId,
            oldPriceValue: oldPrice,
            newPriceValue: price,
            changedAt: DateTime.now(),
            changedBy: _shopId, // Should be deviceId in real app
          ),
        );
        item.priceAsMoney = price;
      }

      item.updatedAt = DateTime.now();
      await _isarService.saveItem(item);

      logSuccess('Item updated: ${item.itemId}');
      AppLogger.inventory('Item updated', details: 'ID: ${item.itemId}');

      // Reload items
      await loadItems(familyId: item.familyId);

      return null; // No error
    } catch (e, stack) {
      logError('Failed to update item', error: e, stackTrace: stack);
      return AppStrings.errorGeneric;
    }
  }

  // ==================== DELETE ITEM ====================

  Future<String?> deleteItem(String itemId) async {
    try {
      logInfo('Deleting item: $itemId');

      final item = await _isarService.getItemById(itemId);
      if (item == null) {
        return AppStrings.errorItemNotFound;
      }

      // Soft delete - mark as inactive
      item.isActive = false;
      item.updatedAt = DateTime.now();
      await _isarService.saveItem(item);

      logSuccess('Item deleted: $itemId');
      AppLogger.inventory('Item deleted', details: 'ID: $itemId');

      // Reload items
      await loadItems(familyId: item.familyId);

      return null; // No error
    } catch (e, stack) {
      logError('Failed to delete item', error: e, stackTrace: stack);
      return AppStrings.errorGeneric;
    }
  }

  // ==================== HELPERS ====================

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void selectFamily(String? familyId) {
    state = state.copyWith(selectedFamilyId: familyId);
    if (familyId != null) {
      loadItems(familyId: familyId);
    }
  }
}

// ==================== PROVIDER ====================

final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>(
  (ref) {
    final isarService = ref.watch(isarServiceProvider);
    final deviceConfig = ref.watch(deviceConfigProvider).value;
    
    if (deviceConfig == null) {
      throw Exception('Device not configured');
    }
    
    return InventoryNotifier(isarService, deviceConfig.shopId);
  },
);