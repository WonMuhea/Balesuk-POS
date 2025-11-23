import 'package:balesuk/core/utils/result.dart';
import 'package:balesuk/data/repositories/shop_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/isar_models.dart';
import '../../../core/utils/app_logger.dart';
import '../../inventory/services/configuration_service.dart';

// ==================== AUTH STATE ====================

class AuthState {
  final DeviceConfig? deviceConfig;
  final Shop? shop;
  final bool isLoading;
  final bool isConfigured;
  final String? errorMessage;

  const AuthState({
    this.deviceConfig,
    this.shop,
    this.isLoading = false,
    this.isConfigured = false,
    this.errorMessage,
  });

  AuthState copyWith({
    DeviceConfig? deviceConfig,
    Shop? shop,
    bool? isLoading,
    bool? isConfigured,
    String? errorMessage,
  }) {
    return AuthState(
      deviceConfig: deviceConfig ?? this.deviceConfig,
      shop: shop ?? this.shop,
      isLoading: isLoading ?? this.isLoading,
      isConfigured: isConfigured ?? this.isConfigured,
      errorMessage: errorMessage,
    );
  }

  bool get isAdmin => deviceConfig?.mode == DeviceMode.ADMIN;
  bool get isUser => deviceConfig?.mode == DeviceMode.USER;
  bool get isShopOpen => shop?.isOpen ?? false;
  String? get shopId => deviceConfig?.shopId;
  String? get deviceId => deviceConfig?.deviceId;
  bool get hasShop => shop != null;
}

class DeviceSetupDto {
  final String deviceId;
  final String shopId;
  final String? shopName;
  final int? familyDigits;
  final int? itemDigits;
  final DeviceMode mode;

  DeviceSetupDto({
    required this.deviceId,
    required this.shopId,
    this.shopName,
    this.familyDigits,
    this.itemDigits,
    required this.mode,
  });

  bool isAdminSetup() {
    return mode == DeviceMode.ADMIN &&
        shopName != null &&
        familyDigits != null &&
        itemDigits != null;
  }

  bool isUserSetup() {
    return mode == DeviceMode.USER;
  }

  bool validate() {
    if (mode == DeviceMode.ADMIN) {
      return shopName != null && familyDigits != null && itemDigits != null;
    } else if (mode == DeviceMode.USER) {
      return true;
    }
    return false;
  }
}

// ==================== AUTH PROVIDER ====================

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> with LoggerMixin {
  final Ref _ref;
  final ShopConfigurationService _configService;

  AuthNotifier(this._ref)
      : _configService = _ref.read(shopConfigurationServiceProvider),
        super(const AuthState(isLoading: true)) {
    _configService.loadInitialConfig();
  }

  // ==================== INITIALIZATION ====================

  Future<void> _initialize() async {
    try {
      logInfo('Initializing auth state...');
      final prefs = await SharedPreferences.getInstance();
      final isConfigured = prefs.getBool('isConfigured') ?? false;

      if (!isConfigured) {
        logInfo('Device not configured');
        state = const AuthState(isConfigured: false, isLoading: false);
        return;
      }

      // Load device config
      final deviceConfigResult = await _config.getDeviceConfig();
      await deviceConfigResult.when(error: (failure) async {
        logError('Fatal initialization error: ${failure.message}',
            error: failure);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isConfigured', false);
        state = const AuthState(isConfigured: false, isLoading: false);
        return;
      }, success: (deviceConfig) async {
        logInfo(
            'Device config loaded: ${deviceConfig.shopId} (${deviceConfig.mode.name})');
        final shopResult =
            await _shopRepository.getShopById(deviceConfig.shopId);
        shopResult.when(error: (failure) {
          if (failure is NotFoundFailure) {
            logError('Shop not found: ${deviceConfig.shopId}');
            state = AuthState(
              deviceConfig: deviceConfig,
              isConfigured: true,
              isLoading: false,
              errorMessage: 'Shop not found',
            );
          } else {
            logError('Error to load shop: ${failure.message}');
            state = AuthState(
              deviceConfig: deviceConfig,
              isConfigured: true,
              isLoading: false,
              errorMessage: 'Fatal Error: ${failure.message}',
            );
          }

          return;
        }, success: (shop) {
          logSuccess(
              'Auth initialized: ${deviceConfig.deviceId} @ ${shop.name}');
          state = AuthState(
            deviceConfig: deviceConfig,
            shop: shop,
            isConfigured: true,
            isLoading: false,
          );
          return;
        });
      });
    } catch (e, stack) {
      logError('Failed to initialize auth', error: e, stackTrace: stack);
      state = AuthState(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  //=================== SETUP METHODS ====================
  Future<String?> setupDevice({
    required DeviceSetupDto setupDto,
  }) async {
    try {
      logInfo(
          'Setting up device: ${setupDto.deviceId} in mode ${setupDto.mode.name}');
      AppLogger.auth('Device setup started',
          details:
              'ID: ${setupDto.deviceId}, Mode: ${setupDto.mode.name} Shop: ${setupDto.shopId}');
      if (setupDto.validate() == false) {
        final errorMsg = 'Invalid setup data for mode ${setupDto.mode.name}';
        logError(errorMsg);
        return errorMsg;
      }
      final shop = await createShop(setupDto);
      final deviceConfig = await createDeviceConfig(setupDto);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isConfigured', true);

      // 2. Update AuthNotifier State
      state = AuthState(
        deviceConfig: deviceConfig,
        shop: shop,
        isConfigured: true,
        isLoading: false,
      );

      // 3. Final Logging
      logSuccess('Setup completed');
      AppLogger.auth('Setup completed',
          details: 'Device: ${setupDto.deviceId}');
      // Mark as configured
    } catch (e, stack) {
      logError('Admin setup failed', error: e, stackTrace: stack);
      AppLogger.error('Admin setup failed', error: e, stackTrace: stack);

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );

      return e.toString();
    }
  }

  // =================== Helpers ===================

  Future<Shop> createShop(DeviceSetupDto setupDto) async {
    final shopDto = CreateShopDto(
      shopId: setupDto.shopId,
      name: setupDto.shopName!,
      familyDigits: setupDto.familyDigits!,
      itemDigits: setupDto.itemDigits!,
    );
    final shopResult = await _shopRepository.createShop(shopDto);
    return shopResult.when(success: (shop) {
      logSuccess('Shop created: ${setupDto.shopId} - ${setupDto.shopName}');
      AppLogger.database('Shop created',
          details: 'ID: ${setupDto.shopId}, Name: ${setupDto.shopName}');
      return shop;
    }, error: (error) {
      logError('Failed to create shop: ${error.message}');
      throw Exception('Failed to create device config');
    });
  }

  Future<DeviceConfig> createDeviceConfig(DeviceSetupDto setupDto) async {
    final deviceConfigDto = CreateDeviceConfigDto(
      deviceId: setupDto.deviceId,
      shopId: setupDto.shopId,
      mode: setupDto.mode,
    );
    final deviceConfigResult =
        await _shopRepository.createDeviceConfig(deviceConfigDto);
    return deviceConfigResult.when(success: (data) async {
      return data;
    }, error: (failure) {
      logError('Failed to create device config: ${failure.message}');
      throw Exception('Failed to create device config');
    });
  }

  // ==================== ADMIN SETUP ====================

  /* Future<String?> setupAdminDevice({
    required String deviceId,
    required String shopId,
    required String shopName,
    required int familyDigits,
    required int itemDigits,
  }) async {
    try {
      logInfo('Setting up admin device: $deviceId');
      AppLogger.auth('Admin setup started',
          details: 'Device: $deviceId, Shop: $shopId');

      state = state.copyWith(isLoading: true, errorMessage: null);

      //final today = DateTime.now().toIso8601String().substring(0, 10);
      if(state.hasShop){
        logInfo('Shop already exists: ${state.shop!.shopId}');
      }
      Shop? shop;
      shopResult.when(
          success: (data) async {
            if (data != null) {
              logInfo('Shop found: ${shop!.name}');
            } else {
              final shopDto = CreateShopDto(
                shopId: shopId,
                name: shopName,
                familyDigits: familyDigits,
                itemDigits: itemDigits,
              );
              shopResult = await _shopRepository.createShop(shopDto);
              logSuccess('Shop created: $shopId - $shopName');
              AppLogger.database('Shop created',
                  details: 'ID: $shopId, Name: $shopName');
            }
            shop = shopResult.dataOrNull;
          },
          error: (failure) async {});

      if (shop != null) {
        logInfo('Using existing shop: $shopId');
      } else {
        // Create new shop
        final shopDto = CreateShopDto(
          shopId: shopId,
          name: shopName,
          familyDigits: familyDigits,
          itemDigits: itemDigits,
        );

        final newshopResult = await _shopRepository.createShop(shopDto);
        shop = newshopResult.dataOrNull;
        logSuccess('Shop created: $shopId - $shopName');
        AppLogger.database('Shop created',
            details: 'ID: $shopId, Name: $shopName');
      }

      // Create device config
      final deviceConfigDto = CreateDeviceConfigDto(
        deviceId: deviceId,
        shopId: shopId,
        mode: DeviceMode.ADMIN,
      );

      final deviceConfigResult =
          await _shopRepository.createDeviceConfig(deviceConfigDto);

      deviceConfigResult.when(success: (data) async {
        return _completeSetup(deviceConfig: data, shop: shop!);
      }, error: (failure) {
        logError('Failed to create device config: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to create device config: ${failure.message}',
        );
        return 'Failed to create device config';
      });

      // Mark as configured
    } catch (e, stack) {
      logError('Admin setup failed', error: e, stackTrace: stack);
      AppLogger.error('Admin setup failed', error: e, stackTrace: stack);

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );

      return e.toString();
    }
  }
 */
  // ==================== USER SETUP ====================

  /* Future<String?> setupUserDevice({
    required String deviceId,
    required String shopId,
  }) async {
    try {
      logInfo('Setting up user device: $deviceId');
      AppLogger.auth('User setup started',details: 'Device: $deviceId, Shop: $shopId');

      state = state.copyWith(isLoading: true, errorMessage: null);

      // Check if shop exists
      final shop = await _shopRepository.getShopById(shopId);

      if (shop == null) {
        logError('Shop not found: $shopId');
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Shop $shopId not found. Please check with admin.',
        );
        return 'Shop not found';
      }

      logInfo('Shop found: ${shop.name}');

      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Create device config
      final deviceConfig = DeviceConfig.create(
        deviceId: deviceId,
        shopId: shopId,
        mode: DeviceMode.USER,
        isConfigured: true,
        currentTrxCounter: 1,
        currentShopOpenDate: today,
        createdAt: DateTime.now(),
      );

      await _isarService.saveDeviceConfig(deviceConfig);
      logSuccess('Device configured: $deviceId (USER)');
      AppLogger.database('Device config saved',
          details: 'ID: $deviceId, Mode: USER');

      // Mark as configured
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isConfigured', true);

      // Update state
      state = AuthState(
        deviceConfig: deviceConfig,
        shop: shop,
        isConfigured: true,
        isLoading: false,
      );

      logSuccess('User setup completed');
      AppLogger.auth('User setup completed', details: 'Device: $deviceId');

      return null; // Success
    } catch (e, stack) {
      logError('User setup failed', error: e, stackTrace: stack);
      AppLogger.error('User setup failed', error: e, stackTrace: stack);

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );

      return e.toString();
    }
  }
 */
  // ==================== QUICK DEV SETUP ====================

  Future<String?> quickDevSetup() async {
    try {
      logInfo('Quick dev setup started');
      AppLogger.auth('Quick dev setup started');
      final setupDto = DeviceSetupDto(
        deviceId: 'ADM001',
        shopId: 'SHOP001',
        shopName: 'Demo Shop (የምሳሌ ሱቅ)',
        familyDigits: 2,
        itemDigits: 4,
        mode: DeviceMode.ADMIN,
      );
      return await setupDevice(setupDto: setupDto);
    } catch (e, stack) {
      logError('Quick dev setup failed', error: e, stackTrace: stack);
      return e.toString();
    }
  }

  // ==================== LOGOUT ====================

  Future<void> logout() async {
    try {
      logInfo('Logging out...');
      AppLogger.auth('Logout initiated');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isConfigured', false);

      // Optionally: Clear device config from database
      // await _isarService.deleteDeviceConfig();

      state = const AuthState(
        isConfigured: false,
        isLoading: false,
      );

      logSuccess('Logout completed');
      AppLogger.auth('Logout completed');
    } catch (e, stack) {
      logError('Logout failed', error: e, stackTrace: stack);
    }
  }

  // ==================== TRANSACTION COUNTER ====================
/* 
  Future<void> incrementTransactionCounter() async {
    final deviceConfig = state.deviceConfig;
    if (deviceConfig == null) return;

    try {
      final newCounter = deviceConfig.currentTrxCounter + 1;

      await _isarService.updateTrxCounter(deviceConfig.deviceId, newCounter);

      deviceConfig.currentTrxCounter = newCounter;
      state = state.copyWith(deviceConfig: deviceConfig);

      logInfo('Transaction counter incremented: $newCounter');
    } catch (e, stack) {
      logError('Failed to increment counter', error: e, stackTrace: stack);
    }
  } */

/*   int getNextTransactionNumber() {
    return state.deviceConfig?.currentTrxCounter ?? 1;
  } */

  // ==================== SHOP OPERATIONS ====================

  Future<void> openShop() async {
    final shop = state.shop;
    final deviceConfig = state.deviceConfig;

    if (shop == null || deviceConfig == null) return;
    try {
      logInfo('Opening shop: ${shop.shopId}');

      final today = DateTime.now().toIso8601String().substring(0, 10);

      await _shopRepository.updateShopStatus(
          shopId: shop.shopId, isOpen: true, currentDate: today);
      shop.isOpen = true;
      shop.currentShopOpenDate = today;
      /*    // Reset transaction counter for new day if needed
      if (deviceConfig.currentShopOpenDate != today) {
        await _isarService.resetTrxCounterForNewDay(
            deviceConfig.deviceId, today);
        deviceConfig.currentTrxCounter = 1;
        deviceConfig.currentShopOpenDate = today;
      }
 */
      state = state.copyWith(shop: shop, deviceConfig: deviceConfig);
      logSuccess('Shop opened');
      AppLogger.business('Shop opened', details: shop.name);
    } catch (e, stack) {
      logError('Failed to open shop', error: e, stackTrace: stack);
    }
  }

  Future<void> closeShop() async {
    final shop = state.shop;
    if (shop == null) return;
    if (!state.isAdmin) {
      logWarning('Only admin can close shop');
      return;
    }

    try {
      logInfo('Closing shop: ${shop.shopId}');

      await _shopRepository.updateShopStatus(
        shopId: shop.shopId,
        isOpen: false,
        currentDate: shop.currentShopOpenDate,
      );

      shop.isOpen = false;
      state = state.copyWith(shop: shop);

      logSuccess('Shop closed');
      AppLogger.business('Shop closed', details: shop.name);
    } catch (e, stack) {
      logError('Failed to close shop', error: e, stackTrace: stack);
    }
  }

  // ==================== RELOAD ====================

  Future<void> reload() async {
    await _initialize();
  }

  // ==================== GETTERS ====================

  bool get isAdmin => state.isAdmin;
  bool get isUser => state.isUser;
  bool get isShopOpen => state.isShopOpen;
  DeviceConfig? get deviceConfig => state.deviceConfig;
  Shop? get shop => state.shop;
}

// ==================== HELPER PROVIDERS ====================

// Check if device is configured
final isConfiguredProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isConfigured;
});

// Check if user is admin
final isAdminProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAdmin;
});

// Check if user is user (not admin)
final isUserProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isUser;
});

// Check if shop is open
final isShopOpenProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isShopOpen;
});

// Get current device config
final currentDeviceConfigProvider = Provider<DeviceConfig?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.deviceConfig;
});

// Get current shop
final currentShopProvider = Provider<Shop?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.shop;
});
