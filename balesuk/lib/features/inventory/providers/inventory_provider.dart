import 'package:balesuk/core/localization/app_success_key.dart';
import 'package:balesuk/features/inventory/services/inventory_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/isar_models.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/money.dart';
import '../../../core/helpers/id_generator.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/providers/providers.dart';
import '../dtos/inventory_dtos.dart';

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
  final InventoryService _inventoryService;
  final Shop _shop;

  InventoryNotifier(this._inventoryService, this._shop)
      : super(InventoryState()) {
    loadFamilies(10, 0);
  }

  // ==================== LOAD DATA ====================

  Future<void> loadFamilies(int page, int offset) async {
    try {
      logInfo('Loading families for shop: ${_shop.shopId}');
      state = state.copyWith(isLoading: true, errorMessage: null);
      final familiesResult =
          await _inventoryService.getFamilies(page, offset, _shop);
      familiesResult.when(
        success: (familyList) {
          logSuccess('Loaded ${familyList?.length} families');
          state = state.copyWith(
            families: familyList,
            isLoading: false,
          );
        },
        error: (failure) {
          logError('Failed to load families: ${failure.message}');
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
        },
      );
    } catch (e, stack) {
      logError('Failed to load families', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.errorGeneric,
      );
    }
  }

  Future<void> loadItems(String familyCode, int page, int offset) async {
    try {
      logInfo(
          'Loading items for family: $familyCode, details: Page: $page, Offset: $offset');
      state = state.copyWith(isLoading: true, errorMessage: null);
      final itemsResultPage = await _inventoryService.getItemsByFamily(
          familyCode, page, offset, _shop);
      itemsResultPage.when(
        success: (items) {
          logSuccess('Loaded ${items?.length} items');
          state = state.copyWith(
            items: items,
            isLoading: false,
          );
        },
        error: (failure) {
          logError('Failed to load items: ${failure.message}');
          state = state.copyWith(
            isLoading: false,
            errorMessage: AppStrings.errorGeneric,
          );
        },
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

  Future<void> searchItems(String query, int page, int offset) async {
    logInfo('Searching items: $query');
    state = state.copyWith(searchQuery: query, isLoading: true);
    final items =
        await _inventoryService.searchItems(query, page, offset, _shop);
    items.when(
      success: (items) {
        logSuccess('Search found ${items.length} items');
        state = state.copyWith(
          items: items,
          isLoading: false,
        );
      },
      error: (failure) {
        logError('Search failed: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
    );
  }

  // ==================== CREATE FAMILY ====================

  Future<String?> createFamily({
    required String name,
    String? description,
    required int familyDigits,
  }) async {
    try {
      logInfo('Creating family: $name');

      final family = CreateFamilyDto(
        shopId: _shop.shopId,
        name: name,
        description: description,
        familyDigits: familyDigits,
      );

      final familyResult = await _inventoryService.createFamily(family);
      familyResult.when(
        success: (createdFamily) {
          logSuccess('Family created: ${createdFamily.familyId}');
          AppLogger.inventory(
            'Family created',
            details: 'ID: ${createdFamily.familyId}, Name: $name',
          );

          // Reload families
          loadFamilies(10, 0);
        },
        error: (failure) {
          logError('Failed to create family: ${failure.message}');
        },
      );

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

      final itemDto = CreateItemDto(
          familyId: familyId,
          shopId: _shop.shopId,
          name: name,
          price: price,
          quantity: quantity,
          minQuantity: minQuantity,
          familyDigits: familyDigits,
          itemDigits: itemDigits,
          attributeValues: attributeValues);
      final newItemResul = await _inventoryService.createItem(itemDto);
      return newItemResul.when(
        success: (createdItem) {
          logSuccess('Item created: ${createdItem.itemId}');
          AppLogger.inventory(
            'Item created',
            details: 'ID: ${createdItem.itemId}, Name: $name',
          );
          loadItems(familyId, 10, 0);
          return AppSuccessKey.itemSavedSuccess.key;
        },
        error: (failure) {
          logError('Failed to create item: ${failure.message}');
          return AppStrings.errorGeneric;
        },
      );
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
    logInfo('Bulk creating ${itemsData.length} items');
    final bulkUpdateDto = BulkCreateItemsDto(
        familyId: familyId,
        shopId: _shop.shopId,
        items: itemsData.map((item) => ItemData.fromJson(item)).toList(),
        familyDigits: familyDigits,
        itemDigits: itemDigits);
    final saveResult = await _inventoryService.saveItemsInBulk(bulkUpdateDto);
    return saveResult.when(
      success: (_) {
        logSuccess('Bulk created items');
        AppLogger.inventory(
          'Bulk items created',
          details: 'in Family ID: $familyId',
        );
        // Reload items
        loadItems(familyId, 10, 0);
        return null;
      },
      error: (failure) {
        logError('Failed to bulk create items: ${failure.message}');
        return failure.message;
      },
    );
  }

  // ==================== UPDATE ITEM ====================

  Future<String?> updateItem({
    required familyId,
    required String itemId,
    String? name,
    Money? price,
    int? quantity,
    int? minQuantity,
    bool? isActive,
  }) async {
    logInfo('Updating item: $itemId');
    final updateDto = UpdateItemDto(
      name: name,
      price: price,
      quantity: quantity,
      minQuantity: minQuantity,
      isActive: isActive,
    );
    final updatedResult =
        await _inventoryService.updateItem(itemId, _shop, updateDto);
    return updatedResult.when(
      success: (updatedItem) {
        logSuccess('Item updated: ${updatedItem.itemId}');
        AppLogger.inventory(
          'Item updated',
          details: 'ID: ${updatedItem.itemId}, Name: ${updatedItem.name}',
        );
        // Reload items
        loadItems(familyId, 10, 0);
        return null;
      },
      error: (failure) {
        logError('Failed to update item: ${failure.message}');
        return failure.message;
      },
    );
  }

  // ==================== DELETE ITEM ====================

  Future<String?> deleteItem(String itemId) async {
    
      logInfo('Deleting item: $itemId');
      final deleteResult = await _inventoryService.deleteItem(itemId, _shop);
      return deleteResult.when(
        success: (_) async {
          logSuccess('Item deleted: $itemId');
          AppLogger.inventory(
            'Item deleted',
            details: 'ID: $itemId',
          );
          final familyId = IdGenerator.extractFamilyCode(
            IdGenerator.parseItemCode(itemId),
            _shop.familyDigits!,
          );
          await loadItems(familyId.toString(), 10, 0);
          return null;
        },
        error: (failure) {
          logError('Failed to delete item: ${failure.message}');
          return failure.message;
        },
      );
  }

  // ==================== HELPERS ====================

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void selectFamily(String? familyId) {
    state = state.copyWith(selectedFamilyId: familyId);
    if (familyId != null) {
      loadItems(familyId, 10, 0);
    }
  }
}

// ==================== PROVIDER ====================

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>(
  (ref) {
    // 1. Correct the typo and watch the service
    final inventoryService = ref.watch(inventoryServiceProvider);
    
    final deviceConfig = ref.watch(deviceConfigProvider).value;
    if (deviceConfig == null || deviceConfig.shopId.isEmpty) {
       throw StateError('Cannot initialize InventoryNotifier: Device configuration or shop ID is missing.');
    }
    final shop = ref.watch(shopNotifierProvider).value;

    // 4. Inject Dependencies
    return InventoryNotifier(inventoryService, shop!);
  },
);