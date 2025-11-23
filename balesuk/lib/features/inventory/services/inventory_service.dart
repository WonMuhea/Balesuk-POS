// ----------------- inventory_service.dart -----------------
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:balesuk/core/localization/app_string_key.dart';
import 'package:balesuk/core/utils/money.dart';

import '../../../core/utils/result.dart';
import '../../../core/localization/app_error_key.dart';
import '../../../data/models/isar_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../dtos/inventory_dtos.dart';
import '../../../core/helpers/id_generator.dart';
import '../../../core/utils/app_logger.dart';
import 'sequence_generator_service.dart';

class InventoryService {
  final InventoryRepository _inventoryRepository;
  final SequenceGeneratorService _sequenceGenerator;
  // final IdGeneratorService _idGenerator; // If ID generation is too complex for here

  InventoryService(this._inventoryRepository, this._sequenceGenerator);

  // ==================== FAMILY OPERATIONS ====================

  /// Creates a new ItemFamily after running validation and business checks.
  Future<Result<ItemFamily>> createFamily(CreateFamilyDto dto) async {
    if (dto.name.trim().isEmpty) {
      return const Error(ValidationFailure(AppErrorKey.fieldRequired,
          params: {'fieldName': AppStringKey.familyName}));
    }
    if (dto.name.length > 100) {
      return const Error(ValidationFailure(AppErrorKey.errinvalidInputLength,
          params: {'fieldName': AppStringKey.familyName, 'value': 100}));
    }

    final existingFamilyResult =
        await _inventoryRepository.searchFamilyByName(dto.shopId, dto.name);
    if (existingFamilyResult.dataOrNull != null) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorDuplicateEntry,
          params: {'fieldName': AppStringKey.familyName}));
    }
    final sequenceResult = await _sequenceGenerator.getNextSequence(
        SequenceType.family, dto.shopId);
    return sequenceResult.when(
      success: (sequence) async {
        final family = ItemFamily.create(
          familyCode: sequence,
          shopId: dto.shopId,
          name: dto.name.trim(),
          description: dto.description?.trim(),
          createdAt: DateTime.now(),
        );

        final repoResult = await _inventoryRepository.createFamily(family);

        return repoResult.when(
            success: (savedFamily) => Success(savedFamily),
            error: (failure) {
              return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
            });
      },
      error: (failure) {
        return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
      },
    );
  }

  Future<Result<List<ItemFamily>?>> getFamilies(
      int pageSize, int offset, Shop shop) async {
    final itemResult = await _inventoryRepository.fetchItemFamilies(
        pageSize, offset, shop.shopId);
    return itemResult.when(success: (family) {
      return Success(family);
    }, error: (failure) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    });
  }

  Future<Result<ItemFamily>> getFamilyById(String familyCode, Shop shop) async {
    final itemResult = await _inventoryRepository.getFamilyById(
        IdGenerator.parseFamilyCode(familyCode), shop.shopId);
    return itemResult.when(success: (family) {
      if (family == null) {
        return Error(NotFoundFailure(AppErrorKey.notFoundWithId,
            params: {'id': familyCode, 'type': AppStringKey.family}));
      }
      return Success(family);
    }, error: (failure) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    });
  }

  /// Deletes a family after checking for associated items.
  Future<Result<void>> deleteFamily(String familyId, Shop shop) async {
    final familyCode = IdGenerator.parseFamilyCode(familyId);
    final itemResult = await _inventoryRepository.getItemsByFamily(
        familyCode, 0, 1, shop.shopId);
    return itemResult.when(success: (items) async {
      if (items?.isNotEmpty == true) {
        return Error(BusinessRuleFailure(AppErrorKey.familyHasActiveItems,
            params: {'familyCode': familyId}));
      }
      final delteResult =
          await _inventoryRepository.deleteFamily(familyCode, shop.shopId);
      return delteResult.when(success: (_) {
        return const Success(null);
      }, error: (failure) {
        return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
      });
    }, error: (failure) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    });
  }

  // ==================== ITEM OPERATIONS ====================

  /// Creates a new Item after validation, family checks, and ID generation.
  Future<Result<Item>> createItem(CreateItemDto dto) async {
    // 1. DTO Validation (The original logic you had in the repo)
    if (dto.name.trim().isEmpty) {
      return const Error(ValidationFailure(AppErrorKey.fieldRequired,
          params: {'fieldName': 'itemName'}));
    }
    if (dto.name.length > 200) {
      return const Error(ValidationFailure(AppErrorKey.errinvalidInputLength,
          params: {'fieldName': 'itemName', 'value': 200}));
    }
    if (dto.price.amount <= 0) {
      return const Error(ValidationFailure(AppErrorKey.mustBeGreaterThan,
          params: {'fieldName': 'price', 'value': 0}));
    }
    if (dto.quantity < 0) {
      return const Error(ValidationFailure(AppErrorKey.mustBeGreaterThan,
          params: {'fieldName': 'quantity', 'value': 0}));
    }
    if (dto.minQuantity < 0) {
      return const Error(ValidationFailure(AppErrorKey.mustBeGreaterThan,
          params: {'fieldName': 'minQuantity', 'value': 0}));
    }
    final existenceCheckResult =
        await checkFamilyExistence(dto.familyCode, dto.shopId);
    if (existenceCheckResult.isError) {
      return Error(existenceCheckResult
          .failureOrNull!); // Returns NotFoundFailure or mapped generic error
    }
    final itemCodeNextSquence =
        await _sequenceGenerator.getNextSequence(SequenceType.item, dto.shopId);
    return itemCodeNextSquence.when(success: (nextItemCode) async {
      final item = toItem(dto, nextItemCode);
      final itemattrs = toItemAttribute(dto.attributeValues, item.itemCode);
      final savedItem =
          await _inventoryRepository.saveItemWihtAttributes(item, itemattrs);
      return savedItem.when(
          success: (_) => Success(item), // Return the created item on success
          error: (failure) {
            return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
          });
    }, error: (failure) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    });
  }

  /// Saves a list of items and their attributes in a single transaction after validation.
  Future<Result<void>> saveItemsInBulk(BulkCreateItemsDto dto) async {
    if (dto.items.isEmpty) {
      return const Error(ValidationFailure(AppErrorKey.errorInvalidInput,
          message: 'The list of items to save cannot be empty.'));
    }

    final existenceCheckResult =
        await checkFamilyExistence(dto.familyCode, dto.shopId);
    if (existenceCheckResult.isError) {
      return Error(existenceCheckResult.failureOrNull!);
    }

    final sequenceResult = await _sequenceGenerator.getNextSequences(
        SequenceType.item, dto.shopId, dto.items.length);

    return sequenceResult.when(success: (sequences) async {
      final List<Failure> validationErrors = [];
      final List<Item> itemsToSave = [];

      for (int i = 0; i < dto.items.length; i++) {
        final itemData = dto.items[i];

        if (itemData.name.trim().isEmpty) {
          validationErrors.add(const ValidationFailure(
              AppErrorKey.fieldRequired,
              params: {'fieldName': 'itemName'}));
        }
        if (itemData.name.length > 200) {
          validationErrors.add(const ValidationFailure(
              AppErrorKey.errinvalidInputLength,
              params: {'fieldName': 'itemName', 'value': 200}));
        }
        if (itemData.price.amount <= 0) {
          validationErrors.add(const ValidationFailure(
              AppErrorKey.mustBeGreaterThan,
              params: {'fieldName': 'price', 'value': 0}));
        }
        if (itemData.quantity < 0) {
          validationErrors.add(const ValidationFailure(
              AppErrorKey.mustBeGreaterThan,
              params: {'fieldName': 'quantity', 'value': 0}));
        }
        if (itemData.minQuantity < 0) {
          validationErrors.add(const ValidationFailure(
              AppErrorKey.mustBeGreaterThan,
              params: {'fieldName': 'minQuantity', 'value': 0}));
        }

        final nextSequence = sequences[i];
        final itemId = IdGenerator.generateItemCode(
          familyCode: dto.familyCode,
          itemSequence: nextSequence,
          familyDigits: dto.familyDigits,
          itemDigits: dto.itemDigits,
        );

        itemsToSave.add(Item.create(
          itemCode: itemId,
          familyCode: dto.familyCode,
          shopId: dto.shopId,
          name: itemData.name.trim(),
          priceValue: itemData.price,
          quantity: itemData.quantity,
          minQuantity: itemData.minQuantity,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      if (validationErrors.isNotEmpty) {
        return Error(validationErrors.first);
      }

      final savedItemsResult =
          await _inventoryRepository.bulkCreateItems(itemsToSave);

      return savedItemsResult.when(
          success: (_) => const Success(null),
          error: (failure) {
            return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
          });
    }, error: (failure) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    });
  }

  Future<Result<void>> deleteItem(String itemId, Shop shop) async {
    final itemResult = await getItemById(itemId, shop);

    return itemResult.when(success: (item) async {
      item.isDeleted = true;
      item.deletedAt = DateTime.now();
      item.updatedAt = DateTime.now();

      final deleteResult = await _inventoryRepository.saveItem(item);

      return deleteResult.when(success: (_) {
        AppLogger.inventory('Item soft-deleted', details: 'Item ID: $itemId');
        return const Success(null);
      }, error: (failure) {
        return Error(BusinessRuleFailure(AppErrorKey.typeDeleteError,
            params: {'type': 'ዕቃ'}, message: failure.message));
      });
    }, error: (failure) {
      if (failure is DatabaseFailure) {
        return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
      }
      return Error(failure);
    });
  }

  Future<Result<void>> checkFamilyExistence(
      int familyCode, String shopId) async {
    final repoResult =
        await _inventoryRepository.familyExists(familyCode, shopId);
    return repoResult.when(success: (exists) {
      if (!exists) {
        // Return a specific, localized NotFoundFailure
        return Error(NotFoundFailure(AppErrorKey.notFound,
            params: {'familyCode': familyCode}));
      }
      return const Success(null);
    }, error: (failure) {
      // Map technical DatabaseFailure to safe generic error
      return Error(BusinessRuleFailure(AppErrorKey.errorGeneric,
          message: failure.message));
    });
  }

  Future<Result<List<Item>?>> getItemsByFamily(
      String familyId, int pageSize, int offset, Shop shop) async {
    final familyCode = IdGenerator.parseFamilyCode(familyId);
    final itemResult = await _inventoryRepository.getItemsByFamily(
        familyCode, pageSize, offset, shop.shopId);
    return itemResult.when(success: (items) {
      return Success(items);
    }, error: (failure) {
      return Error(BusinessRuleFailure(AppErrorKey.errorGeneric,
          message: failure.message));
    });
  }

  Future<Result<Item>> getItemById(String itemId, Shop shop) async {
    final itemCode = IdGenerator.parseToItemCode(itemId, shop.familyDigits!);
    final itemResult =
        await _inventoryRepository.getItemById(itemCode, shop.shopId);
    return itemResult.when(success: (item) {
      if (item == null) {
        return Error(NotFoundFailure(AppErrorKey.notFoundWithId,
            params: {'id': itemId, 'type': AppStringKey.item}));
      }
      return Success(item);
    }, error: (failure) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    });
  }

  Future<Result<List<Item>>> searchItems(
      String query, int page, int offset, Shop shop) async {
    final int? queryInt = int.tryParse(query);
    if (queryInt != null) {
      final itemResult = await getItemById(query, shop);
      return itemResult.when(success: (item) {
        return Success([item]);
      }, error: (failure) {
        return Error(BusinessRuleFailure(AppErrorKey.errorGeneric,
            message: failure.message));
      });
    } else {
      final itemResult = await _inventoryRepository.searchItemsByName(
          query, page, offset, shop.shopId);
      return itemResult.when(success: (items) {
        return Success(items ?? []);
      }, error: (failure) {
        return Error(BusinessRuleFailure(AppErrorKey.errorGeneric,
            message: failure.message));
      });
    }
  }

  Future<Result<Item>> updateItem(
      String itemId, Shop shop, UpdateItemDto dto) async {
    if (!dto.hasUpdates) {
      return const Error(ValidationFailure(AppErrorKey.emptyUpdateData,
          params: {'fieldName': AppStringKey.item}));
    }
    if (dto.name != null && dto.name!.trim().isEmpty) {
      return const Error(ValidationFailure(AppErrorKey.errorInvalidInput,
          params: {'fieldName': AppStringKey.itemName, 'value': 0}));
    }

    if (dto.price != null && dto.price!.amount <= 0) {
      return const Error(ValidationFailure(AppErrorKey.mustBeGreaterThan,
          params: {'fieldName': AppStringKey.price, 'value': 0}));
    }

    if (dto.quantity != null && dto.quantity! < 0) {
      return const Error(ValidationFailure(AppErrorKey.mustBeGreaterThan,
          params: {'fieldName': AppStringKey.quantity, 'value': 0}));
    }
    if (dto.minQuantity != null && dto.minQuantity! < 0) {
      return const Error(ValidationFailure(AppErrorKey.mustBeGreaterThan,
          params: {'fieldName': AppStringKey.minQuantity, 'value': 0}));
    }
    final itemCode = IdGenerator.parseToItemCode(itemId, shop.familyDigits!);
    // Get existing item
    final itemResult = await getItemById(itemId, shop);
    return itemResult.when(success: (item) async {
      if (dto.name != null) item.name = dto.name!.trim();
      if (dto.quantity != null) item.quantity = dto.quantity!;
      if (dto.minQuantity != null) item.minQuantity = dto.minQuantity!;
      if (dto.isActive != null) item.isActive = dto.isActive!;
      final bool isPriceUpdated = dto.price != null &&
          Money.fromDouble(item.price).notEquals(dto.price!);
      Result<Item> finalUpdateResult;
      // Handle price change with history
      if (isPriceUpdated) {
        final oldPrice = item.priceAsMoney;
        final priceHistory = PriceHistory.create(
          itemCode: itemCode,
          oldPriceValue: oldPrice,
          newPriceValue: dto.price!,
          changedAt: DateTime.now(),
          changedBy: item.shopId,
        );
        item.priceAsMoney = dto.price!;
        item.updatedAt = DateTime.now();
        finalUpdateResult = await _inventoryRepository.updateItemAndSaveHistory(
            item, priceHistory);
      } else {
        item.updatedAt = DateTime.now();
        finalUpdateResult = await _inventoryRepository.saveItem(item);
      }
      return finalUpdateResult.when(success: (updatedItem) {
        return Success(updatedItem);
      }, error: (failure) {
        return Error(BusinessRuleFailure(AppErrorKey.typeUpdateError,
            params: {'type': 'ዕቃ'}, message: failure.message));
      });
    }, error: (failure) {
      if (failure is DatabaseFailure) {
        return Error(BusinessRuleFailure(AppErrorKey.errorGeneric,
            params: {'type': 'ዕቃ'}, message: failure.message));
      }
      return Error(failure);
    });
  }

  /// Adjust item quantity
  Future<Result<Item>> adjustQuantity({
    required String itemId,
    required int adjustment,
    String? reason,
    required Shop shop,
  }) async {
    try {
      final itemResult = await getItemById(itemId, shop);

      return itemResult.when(success: (item) async {
        final newQuantity = item.quantity + adjustment;
        if (newQuantity < 0) {
          return Error(BusinessRuleFailure(AppErrorKey.quantityExceedsStock,
              params: {'stock': item.quantity.toString()}));
        }
        item.quantity = newQuantity;
        item.updatedAt = DateTime.now();
        final repoResult = await _inventoryRepository.saveItem(item);
        return repoResult.when(
          success: (_) {
            AppLogger.inventory(
              'Quantity adjusted',
              details:
                  'Item: ${item.itemCode}, Adjustment: $adjustment, New: $newQuantity, Reason: $reason',
            );
            return Success(item);
          },
          error: (failure) {
            return Error(BusinessRuleFailure(AppErrorKey.typeUpdateError,
                params: {'type': 'ዕቃ'}, message: failure.message));
          },
        );
      }, error: (failure) {
        if (failure is DatabaseFailure) {
          return Error(BusinessRuleFailure(AppErrorKey.errorGeneric,
              message: failure.message));
        }
        return Error(failure);
      });
    } catch (e, stack) {
      AppLogger.error('Critical failure adjusting quantity for $itemId',
          error: e, stackTrace: stack);
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    }
  }

  Item toItem(CreateItemDto dto, int nextItemCodeSquence) {
    final itemId = IdGenerator.generateItemCode(
      familyCode: dto.familyCode,
      itemSequence: nextItemCodeSquence,
      familyDigits: dto.familyDigits,
      itemDigits: dto.itemDigits,
    );
    return Item.create(
      itemCode: itemId,
      familyCode: dto.familyCode,
      shopId: dto.shopId,
      name: dto.name.trim(),
      priceValue: dto.price,
      quantity: dto.quantity,
      minQuantity: dto.minQuantity,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  List<ItemAttribute> toItemAttribute(
      Map<int, dynamic>? attributeValues, int itemId) {
    final attributes = <ItemAttribute>[];
    if (attributeValues != null && attributeValues.isNotEmpty) {
      for (final entry in attributeValues.entries) {
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
          itemCode: itemId,
          attributeDefinitionId: attributeId,
          valueText: valueText,
          valueNumber: valueNumber,
          valueDate: valueDate,
          valueBoolean: valueBoolean,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return attributes;
  }
}
// ==================== REPOSITORY PROVIDER ====================

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  final inventoryRepository = ref.watch(inventoryRepositoryProvider);
  final sequenceGeneratorService = ref.watch(sequenceGeneratorProvider);
  return InventoryService(inventoryRepository, sequenceGeneratorService);
});
