/* import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/result.dart';
import '../../core/providers/providers.dart';
import '../database/isar_service.dart';
import '../models/isar_models.dart';

// ==================== DTOs ====================

class CreateAttributeDefinitionDto {
  final String familyId;
  final String name;
  final AttributeDataType dataType;
  final bool isRequired;
  final List<String>? dropdownOptions;
  final int? displayOrder;

  CreateAttributeDefinitionDto({
    required this.familyId,
    required this.name,
    required this.dataType,
    required this.isRequired,
    this.dropdownOptions,
    this.displayOrder,
  });

  // Validation
  Result<void> validate() {
    if (name.trim().isEmpty) {
      return const Error(ValidationFailure('Attribute name is required'));
    }

    if (name.length > 100) {
      return const Error(ValidationFailure('Attribute name must be 100 characters or less'));
    }

    if (dataType == AttributeDataType.DROPDOWN) {
      if (dropdownOptions == null || dropdownOptions!.isEmpty) {
        return const Error(ValidationFailure('Dropdown attributes must have options'));
      }

      if (dropdownOptions!.any((opt) => opt.trim().isEmpty)) {
        return const Error(ValidationFailure('Dropdown options cannot be empty'));
      }

      if (dropdownOptions!.length != dropdownOptions!.toSet().length) {
        return const Error(ValidationFailure('Dropdown options must be unique'));
      }
    }

    return const Success(null);
  }

  int get familyCode => int.parse(familyId);
}

class UpdateAttributeDefinitionDto {
  final String? name;
  final bool? isRequired;
  final List<String>? dropdownOptions;

  UpdateAttributeDefinitionDto({
    this.name,
    this.isRequired,
    this.dropdownOptions,
  });

  bool get hasUpdates => name != null || isRequired != null || dropdownOptions != null;
}

class SaveItemAttributeDto {
  final String itemId;
  final int attributeDefinitionId;
  final dynamic value;

  SaveItemAttributeDto({
    required this.itemId,
    required this.attributeDefinitionId,
    required this.value,
  });

  int get itemCode => int.parse(itemId);
}

// ==================== ATTRIBUTE REPOSITORY ====================

class AttributeRepository with LoggerMixin {
  final IsarService _isarService;

  AttributeRepository(this._isarService);

  // ==================== ATTRIBUTE DEFINITION OPERATIONS ====================

  /// Get attribute definitions for a family
  Future<Result<List<AttributeDefinition>>> getDefinitionsByFamily(String familyCode) async {
    try {
      logInfo('Fetching attribute definitions for family: $familyCode');
      final definitions = await _isarService.getAttributesByFamilyCode(int.parse(familyCode));
      logSuccess('Fetched ${definitions.length} attribute definitions');
      return Success(definitions);
    } catch (e, stack) {
      logError('Failed to fetch attribute definitions', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load attribute definitions',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Get attribute definition by ID
  Future<Result<AttributeDefinition>> getDefinitionById(int attributeId) async {
    try {
      final definition = await _isarService.getAttributeDefinitionById(attributeId);
      if (definition == null) {
        return Error(NotFoundFailure('Attribute definition not found: $attributeId'));
      }
      return Success(definition);
    } catch (e, stack) {
      logError('Failed to fetch attribute definition', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load attribute definition',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Create a new attribute definition
  Future<Result<AttributeDefinition>> createDefinition(CreateAttributeDefinitionDto dto) async {
    try {
      // Validate DTO
      final validation = dto.validate();
      if (validation.isError) {
        return Error(validation.failureOrNull!);
      }

      logInfo('Creating attribute definition: ${dto.name}');

      // Check for duplicate name in family
      final existingDefs = await _isarService.getAttributesByFamilyCode(dto.familyCode);
      final duplicate = existingDefs.any(
        (def) => def.name.toLowerCase() == dto.name.toLowerCase(),
      );

      if (duplicate) {
        return Error(DuplicateFailure(
          'Attribute with name "${dto.name}" already exists in this family',
        ));
      }

      // Get current max display order
      final maxOrder = existingDefs.isEmpty
          ? 0
          : existingDefs.map((a) => a.displayOrder).reduce((a, b) => a > b ? a : b);

      // Create definition
      final definition = AttributeDefinition.create(
        familyCode: dto.familyCode,
        name: dto.name.trim(),
        dataType: dto.dataType,
        isRequired: dto.isRequired,
        dropdownOptions: dto.dropdownOptions,
        displayOrder: dto.displayOrder ?? (maxOrder + 1),
        createdAt: DateTime.now(),
      );

      await _isarService.saveAttributeDefinition(definition);

      logSuccess('Attribute definition created: ${dto.name}');
      AppLogger.inventory(
        'Attribute definition created',
        details: 'Name: ${dto.name}, Type: ${dto.dataType.name}',
      );

      return Success(definition);
    } catch (e, stack) {
      logError('Failed to create attribute definition', error: e, stackTrace: stack);
      AppLogger.error('Failed to create attribute definition', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to create attribute definition',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Bulk create attribute definitions
  Future<Result<List<AttributeDefinition>>> bulkCreateDefinitions({
    required String familyId,
    required List<CreateAttributeDefinitionDto> dtos,
  }) async {
    try {
      if (dtos.isEmpty) {
        return const Error(ValidationFailure('No attribute definitions to create'));
      }

      logInfo('Bulk creating ${dtos.length} attribute definitions');
      final familyCode = int.parse(familyId);

      // Validate all DTOs
      for (final dto in dtos) {
        final validation = dto.validate();
        if (validation.isError) {
          return Error(validation.failureOrNull!);
        }

        if (dto.familyCode != familyCode ) {
          return const Error(ValidationFailure('All attributes must belong to the same family'));
        }
      }

      // Check for duplicate names
      final names = dtos.map((d) => d.name.toLowerCase()).toList();
      if (names.length != names.toSet().length) {
        return const Error(ValidationFailure('Attribute names must be unique'));
      }

      // Check for duplicates with existing attributes
      final existingDefs = await _isarService.getAttributesByFamilyCode(familyCode);
      for (final dto in dtos) {
        final duplicate = existingDefs.any(
          (def) => def.name.toLowerCase() == dto.name.toLowerCase(),
        );
        if (duplicate) {
          return Error(DuplicateFailure(
            'Attribute with name "${dto.name}" already exists',
          ));
        }
      }

      // Create definitions
      final definitions = dtos.asMap().entries.map((entry) {
        return AttributeDefinition.create(
          familyCode: familyCode,
          name: entry.value.name.trim(),
          dataType: entry.value.dataType,
          isRequired: entry.value.isRequired,
          dropdownOptions: entry.value.dropdownOptions,
          displayOrder: entry.key,
          createdAt: DateTime.now(),
        );
      }).toList();

      await _isarService.saveMultipleAttributeDefinitions(definitions);

      logSuccess('Bulk created ${definitions.length} attribute definitions');
      AppLogger.inventory(
        'Bulk attribute definitions created',
        details: 'Count: ${definitions.length}',
      );

      return Success(definitions);
    } catch (e, stack) {
      logError('Failed to bulk create attribute definitions', error: e, stackTrace: stack);
      AppLogger.error('Failed to bulk create attribute definitions', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to bulk create attribute definitions',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Update an attribute definition
  Future<Result<AttributeDefinition>> updateDefinition(
    int attributeId,
    UpdateAttributeDefinitionDto dto,
  ) async {
    try {
      if (!dto.hasUpdates) {
        return const Error(ValidationFailure('No updates provided'));
      }

      logInfo('Updating attribute definition: $attributeId');

      // Get existing definition
      final defResult = await getDefinitionById(attributeId);
      if (defResult.isError) {
        return Error(defResult.failureOrNull!);
      }

      final definition = defResult.dataOrNull!;

      // Validate updates
      if (dto.name != null) {
        if (dto.name!.trim().isEmpty) {
          return const Error(ValidationFailure('Attribute name cannot be empty'));
        }

        if (dto.name!.length > 100) {
          return const Error(ValidationFailure('Attribute name must be 100 characters or less'));
        }

        // Check for duplicate name
        final existingDefs = await _isarService.getAttributesByFamilyCode(definition.familyCode);
        final duplicate = existingDefs.any(
          (def) => def.id != attributeId && def.name.toLowerCase() == dto.name!.toLowerCase(),
        );

        if (duplicate) {
          return Error(DuplicateFailure('Attribute with name "${dto.name}" already exists'));
        }
      }

      if (dto.dropdownOptions != null) {
        if (definition.dataType != AttributeDataType.DROPDOWN) {
          return const Error(BusinessRuleFailure('Cannot set dropdown options on non-dropdown attribute'));
        }

        if (dto.dropdownOptions!.isEmpty) {
          return const Error(ValidationFailure('Dropdown must have at least one option'));
        }

        if (dto.dropdownOptions!.any((opt) => opt.trim().isEmpty)) {
          return const Error(ValidationFailure('Dropdown options cannot be empty'));
        }
      }

      // Apply updates
      if (dto.name != null) definition.name = dto.name!.trim();
      if (dto.isRequired != null) definition.isRequired = dto.isRequired!;
      if (dto.dropdownOptions != null) definition.dropdownOptions = dto.dropdownOptions!;

      await _isarService.saveAttributeDefinition(definition);

      logSuccess('Attribute definition updated: $attributeId');
      AppLogger.inventory('Attribute definition updated', details: 'ID: $attributeId');

      return Success(definition);
    } catch (e, stack) {
      logError('Failed to update attribute definition', error: e, stackTrace: stack);
      AppLogger.error('Failed to update attribute definition', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to update attribute definition',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Delete an attribute definition
  Future<Result<void>> deleteDefinition(int attributeId) async {
    try {
      logInfo('Deleting attribute definition: $attributeId');

      // Check if any items have values for this attribute
      final itemsWithAttribute = await _isarService.getItemsWithAttribute(attributeId);
      if (itemsWithAttribute.isNotEmpty) {
        return Error(BusinessRuleFailure(
          'Cannot delete attribute used by ${itemsWithAttribute.length} items',
        ));
      }

      await _isarService.deleteAttributeDefinition(attributeId);

      logSuccess('Attribute definition deleted: $attributeId');
      AppLogger.inventory('Attribute definition deleted', details: 'ID: $attributeId');

      return const Success(null);
    } catch (e, stack) {
      logError('Failed to delete attribute definition', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to delete attribute definition',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  // ==================== ITEM ATTRIBUTE OPERATIONS ====================

  /// Get attributes for an item
  Future<Result<List<ItemAttribute>>> getAttributesByItem(String itemId) async {
    try {
      logInfo('Fetching attributes for item: $itemId');
      final itemCode = int.parse(itemId);
      final attributes = await _isarService.getItemAttributesByCode(itemCode);
      logSuccess('Fetched ${attributes.length} attributes');
      return Success(attributes);
    } catch (e, stack) {
      logError('Failed to fetch item attributes', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load item attributes',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Save a single item attribute
  Future<Result<ItemAttribute>> saveItemAttribute(SaveItemAttributeDto dto) async {
    try {
      logInfo('Saving attribute for item: ${dto.itemId}');

      // Verify attribute definition exists
      final defResult = await getDefinitionById(dto.attributeDefinitionId);
      if (defResult.isError) {
        return Error(defResult.failureOrNull!);
      }

      final definition = defResult.dataOrNull!;

      // Validate value based on data type
      final validation = _validateAttributeValue(definition, dto.value);
      if (validation.isError) {
        return Error(validation.failureOrNull!);
      }

      // Determine which field to set based on value type
      String? valueText;
      double? valueNumber;
      String? valueDate;
      bool? valueBoolean;

      if (dto.value is String) {
        valueText = (dto.value as String).trim();
      } else if (dto.value is num) {
        valueNumber = (dto.value as num).toDouble();
      } else if (dto.value is bool) {
        valueBoolean = dto.value as bool;
      } else if (dto.value is DateTime) {
        valueDate = (dto.value as DateTime).toIso8601String().substring(0, 10);
      }

      // Check if attribute already exists
      final existingAttrs = await _isarService.getItemAttributesByCode(dto.itemCode);
      final existing = existingAttrs.where(
        (a) => a.attributeDefinitionId == dto.attributeDefinitionId,
      ).firstOrNull;

      ItemAttribute attribute;

      if (existing != null) {
        // Update existing
        existing.valueText = valueText;
        existing.valueNumber = valueNumber;
        existing.valueDate = valueDate;
        existing.valueBoolean = valueBoolean;
        existing.updatedAt = DateTime.now();
        await _isarService.saveItemAttribute(existing);
        attribute = existing;
      } else {
        // Create new
        attribute = ItemAttribute.create(
          itemCode: dto.itemCode,
          attributeDefinitionId: dto.attributeDefinitionId,
          valueText: valueText,
          valueNumber: valueNumber,
          valueDate: valueDate,
          valueBoolean: valueBoolean,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _isarService.saveItemAttribute(attribute);
      }

      logSuccess('Item attribute saved');
      return Success(attribute);
    } catch (e, stack) {
      logError('Failed to save item attribute', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to save item attribute',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Bulk save item attributes
  Future<Result<List<ItemAttribute>>> bulkSaveItemAttributes({
    required String itemId,
    required Map<int, dynamic> attributeValues,
  }) async {
    try {
      if (attributeValues.isEmpty) {
        return const Error(ValidationFailure('No attributes to save'));
      }

      logInfo('Bulk saving ${attributeValues.length} attributes for item: $itemId');
      final itemCode = int.parse(itemId);
      final attributes = <ItemAttribute>[];

      for (final entry in attributeValues.entries) {
        final attributeId = entry.key;
        final value = entry.value;

        // Verify definition exists and validate value
        final defResult = await getDefinitionById(attributeId);
        if (defResult.isError) {
          return Error(defResult.failureOrNull!);
        }

        final definition = defResult.dataOrNull!;
        final validation = _validateAttributeValue(definition, value);
        if (validation.isError) {
          return Error(validation.failureOrNull!);
        }

        // Determine which field to set based on value type
        String? valueText;
        double? valueNumber;
        String? valueDate;
        bool? valueBoolean;

        if (value is String) {
          valueText = (value).trim();
        } else if (value is num) {
          valueNumber = (value).toDouble();
        } else if (value is bool) {
          valueBoolean = value;
        } else if (value is DateTime) {
          valueDate = (value).toIso8601String().substring(0, 10);
        }

        attributes.add(ItemAttribute.create(
          itemCode: itemCode,
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

      logSuccess('Bulk saved ${attributes.length} item attributes');
      return Success(attributes);
    } catch (e, stack) {
      logError('Failed to bulk save item attributes', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to bulk save item attributes',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Delete an item attribute
  Future<Result<void>> deleteItemAttribute(int attributeId) async {
    try {
      logInfo('Deleting item attribute: $attributeId');
      await _isarService.deleteItemAttribute(attributeId);
      logSuccess('Item attribute deleted');
      return const Success(null);
    } catch (e, stack) {
      logError('Failed to delete item attribute', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to delete item attribute',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  // ==================== VALIDATION ====================

  /// Validate required attributes are provided
  Future<Result<void>> validateRequiredAttributes({
    required String familyId,
    required Map<int, dynamic> providedValues,
  }) async {
    try {
      final definitionsResult = await getDefinitionsByFamily(familyId);
      if (definitionsResult.isError) {
        return Error(definitionsResult.failureOrNull!);
      }

      final definitions = definitionsResult.dataOrNull!;
      final requiredDefs = definitions.where((d) => d.isRequired);
      final missingAttributes = <String>[];

      for (final def in requiredDefs) {
        final value = providedValues[def.id];
        if (value == null || (value is String && value.trim().isEmpty)) {
          missingAttributes.add(def.name);
        }
      }

      if (missingAttributes.isNotEmpty) {
        return Error(ValidationFailure(
          'Missing required attributes: ${missingAttributes.join(', ')}',
        ));
      }

      return const Success(null);
    } catch (e, stack) {
      logError('Failed to validate required attributes', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to validate required attributes',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Validate attribute value based on definition
  Result<void> _validateAttributeValue(AttributeDefinition definition, dynamic value) {
    if (value == null) {
      if (definition.isRequired) {
        return Error(ValidationFailure('${definition.name} is required'));
      }
      return const Success(null);
    }

    switch (definition.dataType) {
      case AttributeDataType.TEXT:
        if (value is! String) {
          return Error(ValidationFailure('${definition.name} must be text'));
        }
        if (definition.isRequired && (value).trim().isEmpty) {
          return Error(ValidationFailure('${definition.name} cannot be empty'));
        }
        break;

      case AttributeDataType.NUMBER:
        if (value is! num) {
          return Error(ValidationFailure('${definition.name} must be a number'));
        }
        break;

      case AttributeDataType.DATE:
        if (value is! DateTime && value is! String) {
          return Error(ValidationFailure('${definition.name} must be a date'));
        }
        break;

      case AttributeDataType.BOOLEAN:
        if (value is! bool) {
          return Error(ValidationFailure('${definition.name} must be true or false'));
        }
        break;

      case AttributeDataType.DROPDOWN:
        if (value is! String) {
          return Error(ValidationFailure('${definition.name} must be text'));
        }
        if (definition.dropdownOptions != null &&
            !definition.dropdownOptions!.contains(value)) {
          return Error(ValidationFailure(
            '${definition.name} must be one of: ${definition.dropdownOptions!.join(', ')}',
          ));
        }
        break;
    }

    return const Success(null);
  }

  // ==================== HELPERS ====================

  /// Get attribute value for an item
  Future<Result<dynamic>> getAttributeValue({
    required String itemId,
    required int attributeDefinitionId,
  }) async {
    try {
      final attributesResult = await getAttributesByItem(itemId);
      if (attributesResult.isError) {
        return Error(attributesResult.failureOrNull!);
      }

      final attributes = attributesResult.dataOrNull!;
      final attribute = attributes.where(
        (a) => a.attributeDefinitionId == attributeDefinitionId,
      ).firstOrNull;

      if (attribute == null) {
        return const Success(null);
      }

      // Return the appropriate value based on which field is set
      if (attribute.valueText != null) return Success(attribute.valueText);
      if (attribute.valueNumber != null) return Success(attribute.valueNumber);
      if (attribute.valueBoolean != null) return Success(attribute.valueBoolean);
      if (attribute.valueDate != null) return Success(DateTime.parse(attribute.valueDate!));

      return const Success(null);
    } catch (e, stack) {
      logError('Failed to get attribute value', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to get attribute value',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }
}

// ==================== REPOSITORY PROVIDER ====================

final attributeRepositoryProvider = Provider<AttributeRepository>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return AttributeRepository(isarService);
}); */