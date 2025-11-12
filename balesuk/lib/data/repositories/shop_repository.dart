import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/result.dart';
import '../../core/providers/providers.dart';
import '../database/isar_service.dart';
import '../models/isar_models.dart';

// ==================== DTOs ====================

class CreateShopDto {
  final String shopId;
  final String name;
  final int familyDigits;
  final int itemDigits;

  CreateShopDto({
    required this.shopId,
    required this.name,
    required this.familyDigits,
    required this.itemDigits,
  });

  Result<void> validate() {
    if (shopId.trim().isEmpty) {
      return Error(ValidationFailure('Shop ID is required'));
    }

    if (shopId.length < 3) {
      return Error(ValidationFailure('Shop ID must be at least 3 characters'));
    }

    if (name.trim().isEmpty) {
      return Error(ValidationFailure('Shop name is required'));
    }

    if (name.length > 200) {
      return Error(ValidationFailure('Shop name must be 200 characters or less'));
    }

    if (familyDigits < 1 || familyDigits > 4) {
      return Error(ValidationFailure('Family digits must be between 1 and 4'));
    }

    if (itemDigits < 1 || itemDigits > 6) {
      return Error(ValidationFailure('Item digits must be between 1 and 6'));
    }

    return const Success(null);
  }
}

class CreateDeviceConfigDto {
  final String deviceId;
  final String shopId;
  final DeviceMode mode;

  CreateDeviceConfigDto({
    required this.deviceId,
    required this.shopId,
    required this.mode,
  });

  Result<void> validate() {
    if (deviceId.trim().isEmpty) {
      return Error(ValidationFailure('Device ID is required'));
    }

    if (deviceId.length < 3) {
      return Error(ValidationFailure('Device ID must be at least 3 characters'));
    }

    if (shopId.trim().isEmpty) {
      return Error(ValidationFailure('Shop ID is required'));
    }

    return const Success(null);
  }
}

// ==================== SHOP REPOSITORY ====================

class ShopRepository with LoggerMixin {
  final IsarService _isarService;

  ShopRepository(this._isarService);

  // ==================== SHOP OPERATIONS ====================

  /// Get shop by ID
  Future<Result<Shop>> getShopById(String shopId) async {
    try {
      logInfo('Fetching shop: $shopId');
      final shop = await _isarService.getShop(shopId);
      
      if (shop == null) {
        return Error(NotFoundFailure('Shop not found: $shopId'));
      }
      
      logSuccess('Shop fetched: ${shop.name}');
      return Success(shop);
    } catch (e, stack) {
      logError('Failed to fetch shop', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load shop',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Create a new shop
  Future<Result<Shop>> createShop(CreateShopDto dto) async {
    try {
      // Validate
      final validation = dto.validate();
      if (validation.isError) {
        return Error(validation.failureOrNull!);
      }

      logInfo('Creating shop: ${dto.name}');

      // Check if shop ID already exists
      final existing = await _isarService.getShop(dto.shopId);
      if (existing != null) {
        return Error(DuplicateFailure('Shop with ID "${dto.shopId}" already exists'));
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);

      final shop = Shop.create(
        shopId: dto.shopId.trim().toUpperCase(),
        name: dto.name.trim(),
        familyDigits: dto.familyDigits,
        itemDigits: dto.itemDigits,
        createdAt: DateTime.now(),
        isOpen: true,
        currentShopOpenDate: today,
      );

      await _isarService.saveShop(shop);

      logSuccess('Shop created: ${shop.shopId} - ${shop.name}');
      AppLogger.database('Shop created', details: 'ID: ${shop.shopId}, Name: ${shop.name}');

      return Success(shop);
    } catch (e, stack) {
      logError('Failed to create shop', error: e, stackTrace: stack);
      AppLogger.error('Failed to create shop', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to create shop',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Update shop status (open/close)
  Future<Result<Shop>> updateShopStatus({
    required String shopId,
    required bool isOpen,
    String? currentDate,
  }) async {
    try {
      logInfo('Updating shop status: $shopId -> ${isOpen ? 'OPEN' : 'CLOSED'}');

      final shopResult = await getShopById(shopId);
      if (shopResult.isError) {
        return Error(shopResult.failureOrNull!);
      }

      final shop = shopResult.dataOrNull!;
      final date = currentDate ?? DateTime.now().toIso8601String().substring(0, 10);

      await _isarService.updateShopStatus(shopId, isOpen, date);

      shop.isOpen = isOpen;
      shop.currentShopOpenDate = date;

      logSuccess('Shop status updated: ${shop.shopId}');
      AppLogger.business(
        isOpen ? 'Shop opened' : 'Shop closed',
        details: shop.name,
      );

      return Success(shop);
    } catch (e, stack) {
      logError('Failed to update shop status', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to update shop status',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Open shop
  Future<Result<Shop>> openShop(String shopId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await updateShopStatus(
      shopId: shopId,
      isOpen: true,
      currentDate: today,
    );
  }

  /// Close shop
  Future<Result<Shop>> closeShop(String shopId) async {
    final shopResult = await getShopById(shopId);
    if (shopResult.isError) {
      return Error(shopResult.failureOrNull!);
    }

    final shop = shopResult.dataOrNull!;
    
    return await updateShopStatus(
      shopId: shopId,
      isOpen: false,
      currentDate: shop.currentShopOpenDate,
    );
  }

  // ==================== DEVICE CONFIG OPERATIONS ====================

  /// Get device configuration
  Future<Result<DeviceConfig>> getDeviceConfig() async {
    try {
      logInfo('Fetching device config');
      final config = await _isarService.getDeviceConfig();
      
      if (config == null) {
        return Error(NotFoundFailure('Device not configured'));
      }
      
      logSuccess('Device config fetched: ${config.deviceId}');
      return Success(config);
    } catch (e, stack) {
      logError('Failed to fetch device config', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load device configuration',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Create device configuration
  Future<Result<DeviceConfig>> createDeviceConfig(CreateDeviceConfigDto dto) async {
    try {
      // Validate
      final validation = dto.validate();
      if (validation.isError) {
        return Error(validation.failureOrNull!);
      }

      logInfo('Creating device config: ${dto.deviceId}');

      // Check if device already configured
      final existing = await _isarService.getDeviceConfig();
      if (existing != null) {
        return Error(DuplicateFailure('Device already configured as ${existing.deviceId}'));
      }

      // Verify shop exists
      final shop = await _isarService.getShop(dto.shopId);
      if (shop == null) {
        return Error(NotFoundFailure('Shop not found: ${dto.shopId}'));
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);

      final config = DeviceConfig.create(
        deviceId: dto.deviceId.trim().toUpperCase(),
        shopId: dto.shopId.trim().toUpperCase(),
        mode: dto.mode,
        isConfigured: true,
        currentTrxCounter: 1,
        currentShopOpenDate: today,
        createdAt: DateTime.now(),
      );

      await _isarService.saveDeviceConfig(config);

      logSuccess('Device configured: ${config.deviceId} (${config.mode.name})');
      AppLogger.database(
        'Device config saved',
        details: 'ID: ${config.deviceId}, Mode: ${config.mode.name}',
      );

      return Success(config);
    } catch (e, stack) {
      logError('Failed to create device config', error: e, stackTrace: stack);
      AppLogger.error('Failed to create device config', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to configure device',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Update transaction counter
  Future<Result<DeviceConfig>> updateTransactionCounter({
    required String deviceId,
    required int newCounter,
  }) async {
    try {
      if (newCounter < 1) {
        return Error(ValidationFailure('Transaction counter must be at least 1'));
      }

      logInfo('Updating transaction counter: $deviceId -> $newCounter');

      await _isarService.updateTrxCounter(deviceId, newCounter);

      final configResult = await getDeviceConfig();
      if (configResult.isError) {
        return Error(configResult.failureOrNull!);
      }

      final config = configResult.dataOrNull!;
      config.currentTrxCounter = newCounter;

      logSuccess('Transaction counter updated: $newCounter');

      return Success(config);
    } catch (e, stack) {
      logError('Failed to update transaction counter', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to update transaction counter',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Increment transaction counter
  Future<Result<DeviceConfig>> incrementTransactionCounter() async {
    try {
      final configResult = await getDeviceConfig();
      if (configResult.isError) {
        return Error(configResult.failureOrNull!);
      }

      final config = configResult.dataOrNull!;
      final newCounter = config.currentTrxCounter + 1;

      return await updateTransactionCounter(
        deviceId: config.deviceId,
        newCounter: newCounter,
      );
    } catch (e, stack) {
      logError('Failed to increment transaction counter', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to increment transaction counter',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Reset for new day
  Future<Result<DeviceConfig>> resetForNewDay(String deviceId, String newDate) async {
    try {
      logInfo('Resetting for new day: $deviceId -> $newDate');

      await _isarService.resetTrxCounterForNewDay(deviceId, newDate);

      final configResult = await getDeviceConfig();
      if (configResult.isError) {
        return Error(configResult.failureOrNull!);
      }

      final config = configResult.dataOrNull!;
      config.currentTrxCounter = 1;
      config.currentShopOpenDate = newDate;

      logSuccess('Reset for new day: $newDate');
      AppLogger.business('New day started', details: newDate);

      return Success(config);
    } catch (e, stack) {
      logError('Failed to reset for new day', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to reset for new day',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Check and reset for new day if needed
  Future<Result<DeviceConfig>> checkAndResetForNewDay() async {
    try {
      final configResult = await getDeviceConfig();
      if (configResult.isError) {
        return Error(configResult.failureOrNull!);
      }

      final config = configResult.dataOrNull!;
      final today = DateTime.now().toIso8601String().substring(0, 10);

      if (config.currentShopOpenDate != today) {
        logInfo('New day detected, resetting transaction counter');
        return await resetForNewDay(config.deviceId, today);
      }

      return Success(config);
    } catch (e, stack) {
      logError('Failed to check and reset for new day', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to check for new day',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Get next transaction number
  Future<Result<int>> getNextTransactionNumber() async {
    try {
      final configResult = await getDeviceConfig();
      if (configResult.isError) {
        return Error(configResult.failureOrNull!);
      }

      final config = configResult.dataOrNull!;
      return Success(config.currentTrxCounter);
    } catch (e, stack) {
      logError('Failed to get next transaction number', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to get transaction number',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  // ==================== VALIDATION ====================

  /// Check if device can perform admin operations
  Future<Result<bool>> canPerformAdminOperations() async {
    try {
      final configResult = await getDeviceConfig();
      if (configResult.isError) {
        return Error(configResult.failureOrNull!);
      }

      final config = configResult.dataOrNull!;
      final isAdmin = config.mode == DeviceMode.ADMIN;

      if (!isAdmin) {
        return Error(BusinessRuleFailure('Only admin devices can perform this operation'));
      }

      return const Success(true);
    } catch (e, stack) {
      logError('Failed to check admin permissions', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to check permissions',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Check if shop is open
  Future<Result<bool>> isShopOpen(String shopId) async {
    try {
      final shopResult = await getShopById(shopId);
      if (shopResult.isError) {
        return Error(shopResult.failureOrNull!);
      }

      final shop = shopResult.dataOrNull!;
      return Success(shop.isOpen);
    } catch (e, stack) {
      logError('Failed to check shop status', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to check shop status',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }
}

// ==================== REPOSITORY PROVIDER ====================

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return ShopRepository(isarService);
});