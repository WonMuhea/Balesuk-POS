import 'package:balesuk/features/inventory/dtos/config_dtos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/result.dart';
import '../../core/providers/providers.dart';
import '../database/isar_service.dart';
import '../models/isar_models.dart';

// ==================== SHOP REPOSITORY ====================

class ShopRepository with LoggerMixin {
  final IsarService _isarService;

  ShopRepository(this._isarService);

  // ==================== SHOP OPERATIONS ====================

  Future<Result<ShopConfigurationDto>> saveSetup(Shop shop, DeviceConfig deviceConfig) async {
    try {
      logInfo('Saving setup for shop: ${shop.shopId} and device: ${deviceConfig.deviceId}');
      await _isarService.runInTransaction(() async {
        await _isarService.saveShop(shop);
        await _isarService.saveDeviceConfig(deviceConfig);
      });
      return Success(ShopConfigurationDto(
        deviceConfig: deviceConfig,
        shop: shop,
      ));
    } catch (e, stack) {
      logError('Failed to save setup', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to save setup',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Get shop by ID
  Future<Result<Shop?>> getShopById(String shopId) async {
    try {
      logInfo('Fetching shop: $shopId');
      final shop = await _isarService.getShop(shopId);
      logSuccess('Shop fetched: $shopId');
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
  Future<Result<Shop>> saveShop(Shop shop) async {
    try {
      logInfo('Creating shop: ${shop.shopId} - ${shop.name}');
      await _isarService.saveShop(shop);
      logSuccess('Shop created: ${shop.shopId} - ${shop.name}');
      AppLogger.database('Shop created',
          details: 'ID: ${shop.shopId}, Name: ${shop.name}');
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

  // ==================== DEVICE CONFIG OPERATIONS ====================

  /// Get device configuration
  Future<Result<DeviceConfig?>> getDeviceConfig() async {
    try {
      logInfo('Fetching device config');
      final deviceConfig = await _isarService.getDeviceConfig();
      logSuccess('Device config fetched: ${deviceConfig?.deviceId}');
      return Success(deviceConfig);
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
  Future<Result<DeviceConfig>> saveDeviceConfig(DeviceConfig deviceConfig) async {
    try {
      logInfo(
          'Creating device config: ${deviceConfig.deviceId} (${deviceConfig.mode.name})');
      await _isarService.saveDeviceConfig(deviceConfig);

      logSuccess('Device configured: ${deviceConfig.deviceId} (${deviceConfig.mode.name})');
      AppLogger.database(
        'Device config saved',
        details: 'ID: ${deviceConfig.deviceId}, Mode: ${deviceConfig.mode.name}',
      );
      return Success(deviceConfig);
    } catch (e, stack) {
      logError('Failed to create device config', error: e, stackTrace: stack);
      AppLogger.error('Failed to create device config',
          error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to configure device',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Reset for new day
  Future<Result<DeviceConfig>> resetForNewDay(
      String deviceId, String newDate) async {
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
      logError('Failed to check and reset for new day',
          error: e, stackTrace: stack);
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
      logError('Failed to get next transaction number',
          error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to get transaction number',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  // ==================== VALIDATION ====================

/*   /// Check if device can perform admin operations
  Future<Result<bool>> canPerformAdminOperations() async {
    try {
      final configResult = await getDeviceConfig();
      if (configResult.isError) {
        return Error(configResult.failureOrNull!);
      }

      final config = configResult.dataOrNull!;
      final isAdmin = config.mode == DeviceMode.ADMIN;

      if (!isAdmin) {
        return const Error(BusinessRuleFailure(
            'Only admin devices can perform this operation'));
      }

      return const Success(true);
    } catch (e, stack) {
      logError('Failed to check admin permissions',
          error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to check permissions',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  } */

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


final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return ShopRepository(isarService);
});