import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:balesuk/core/localization/app_error_key.dart';
import 'package:balesuk/core/localization/app_string_key.dart';
import 'package:balesuk/data/models/isar_models.dart';
import 'package:balesuk/features/auth/providers/auth_provider.dart';
import 'package:balesuk/features/inventory/dtos/config_dtos.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../core/utils/result.dart';
// Import your models and DTOs (Result, Shop, DeviceConfig, CreateShopDto, etc.)

class ShopConfigurationService {
  final ShopRepository _shopRepository;

  ShopConfigurationService(this._shopRepository);

  // ==================== SETUP LOGIC ====================
  Future<Result<ShopConfigurationDto>> doSetup({
    required DeviceSetupDto setupDto,
  }) async {
    //logInfo('Starting device setup: ${setupDto.deviceId} in mode ${setupDto.mode.name}');
    final validationResult = validate(setupDto);
    if (validationResult.isSuccess) {
      final existingDeviceConfigResult =
          await _shopRepository.getDeviceConfig();
      final existingShop = await _shopRepository.getShopById(setupDto.shopId);
      if (existingDeviceConfigResult.isSuccess &&
          existingDeviceConfigResult.dataOrNull != null) {
        final existingConfig = existingDeviceConfigResult.dataOrNull!;
        return Error(DuplicateFailure(AppErrorKey.errorDuplicateEntry, params: {
          'field': AppStringKey.deviceId,
          'value': existingConfig.deviceId
        }));
      }
      if (existingShop.isSuccess || existingShop.dataOrNull != null) {
        return Error(DuplicateFailure(AppErrorKey.errorDuplicateEntry,
            params: {'id': AppStringKey.shopId, 'value': setupDto.shopId}));
      }
      final shop = Shop.create(
        shopId: setupDto.shopId,
        name: setupDto.shopName!,
        familyDigits: setupDto.familyDigits!,
        itemDigits: setupDto.itemDigits!,
        createdAt: DateTime.now(),
        isOpen: false,
        currentShopOpenDate: '',
      );
      final deviceConfig = DeviceConfig.create(
        deviceId: setupDto.deviceId,
        shopId: setupDto.shopId,
        mode: setupDto.mode,
        isConfigured: true,
        currentTrxCounter: 1,
        currentShopOpenDate: '',
        createdAt: DateTime.now(),
      );
      final setupResult = await _shopRepository.saveSetup(shop, deviceConfig);
      return setupResult.when(
        success: (shopSetup) {
          //logSuccess('Device setup completed: ${setupDto.deviceId} with shop ${setupDto.shopId}');
          return Success(shopSetup);
        },
        error: (failure) {
          //logError('Device setup failed: ${failure.message}');
          return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
        },
      );
    } else {
      //logError('Device setup validation failed: ${validationResult.failureOrNull!.message}');
      return Error(validationResult.failureOrNull!);
    }
  }

  // ==================== INITIALIZATION LOGIC ====================
  Future<Result<ShopConfigurationDto?>> loadInitialConfig() async {
    // 1. Load device config
    final deviceConfigResult = await _shopRepository.getDeviceConfig();

    return deviceConfigResult.when(error: (failure) async {
      //logError('Failed to load device config: ${failure.message}');
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    }, success: (deviceConfig) async {
      if (deviceConfig == null) {
        //logInfo('Device is not configured yet.');
        return const Success(null);
      } else {
        //logSuccess('Device config loaded: ${deviceConfig.deviceId}');
        final shopResult =
            await _shopRepository.getShopById(deviceConfig.shopId);
        return shopResult.when(error: (failure) {
          // logError('Failed to load shop for device config: ${failure.message}');
          return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
        }, success: (shop) {
          // logSuccess('Shop successfully loaded: ${shop.name}');
          if (shop == null) {
            //  logError('Shop with ID ${deviceConfig.shopId} not found for device config ${deviceConfig.deviceId}');
            return const Error(NotFoundFailure(AppErrorKey.notFound,
                params: {'type': AppStringKey.shop}));
          }
          return Success(ShopConfigurationDto(
            deviceConfig: deviceConfig,
            shop: shop,
          ));
        });
      }
    });
  }

  // ==================== SHOP OPERATIONS ====================
  /// Open shop
  Future<Result<Shop>> openShop(String shopId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final shopResult = await _shopRepository.getShopById(shopId);
    return shopResult.when(success: (shop) async {
      if (shop == null) {
        return Error(NotFoundFailure(AppErrorKey.notFoundWithId,
            params: {'type': AppStringKey.shop, 'id': shopId}));
      }
      shop.isOpen = true;
      shop.currentShopOpenDate = today;
      final saveShopResult = await _shopRepository.saveShop(shop);
      return saveShopResult.when(success: (savedShop) {
        return Success(savedShop);
      }, error: (failure) {
        return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
      });
    }, error: (failure) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    });
  }

  /// Close shop
  Future<Result<Shop>> closeShop(String shopId) async {
    final shopResult = await _shopRepository.getShopById(shopId);
    return shopResult.when(success: (shop) async {
      if (shop == null) {
        return Error(NotFoundFailure(AppErrorKey.notFoundWithId,
            params: {'type': AppStringKey.shop, 'id': shopId}));
      }
      shop.isOpen = false;
      final saveShopResult = await _shopRepository.saveShop(shop);
      return saveShopResult.when(success: (savedShop) {
        return Success(savedShop);
      }, error: (failure) {
        return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
      });
    }, error: (failure) {
      return const Error(BusinessRuleFailure(AppErrorKey.errorGeneric));
    });
  }

  Result<void> validate(DeviceSetupDto createShopDto) {
    if (createShopDto.shopId.trim().isEmpty) {
      return const Error(ValidationFailure(AppErrorKey.errorRequiredField,
          params: {'field': AppStringKey.shopId}));
    }
    if (createShopDto.shopId.length < 3) {
      return const Error(ValidationFailure(AppErrorKey.errinvalidInputLength,
          params: {'field': AppStringKey.shopId, 'min': 3}));
    }
    if (createShopDto.isAdminSetup() && createShopDto.shopName!.length > 200) {
      return const Error(ValidationFailure(AppErrorKey.errinvalidInputLength,
          params: {'field': AppStringKey.shopName, 'max': 200}));
    }
    if (createShopDto.isAdminSetup() &&
        (createShopDto.familyDigits! < 1 || createShopDto.familyDigits! > 4)) {
      return const Error(ValidationFailure(AppErrorKey.errinvalidInputRange,
          params: {'field': AppStringKey.familyDigits, 'min': 1, 'max': 4}));
    }
    if (createShopDto.isAdminSetup() &&
        (createShopDto.itemDigits! < 1 || createShopDto.itemDigits! > 6)) {
      return const Error(ValidationFailure(AppErrorKey.errinvalidInputRange,
          params: {'field': AppStringKey.itemDigits, 'min': 1, 'max': 6}));
    }
    return const Success(null);
  }
}

// ==================== REPOSITORY PROVIDER ====================

final shopConfigurationServiceProvider = Provider<ShopConfigurationService>((ref) {
  final shopRepository = ref.watch(shopRepositoryProvider);
  return ShopConfigurationService(shopRepository);
});

