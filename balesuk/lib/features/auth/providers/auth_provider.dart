import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/database/isar_service.dart';
import '../../../data/models/isar_models.dart';
import '../../../core/utils/app_logger.dart';

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
}

// ==================== AUTH PROVIDER ====================

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> with LoggerMixin {
  final Ref _ref;
  IsarService get _isarService => IsarService.instance;

  AuthNotifier(this._ref) : super(const AuthState(isLoading: true)) {
    _initialize();
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
      final deviceConfig = await _isarService.getDeviceConfig();
      
      if (deviceConfig == null) {
        logWarning('Device config not found despite isConfigured=true');
        await prefs.setBool('isConfigured', false);
        state = const AuthState(isConfigured: false, isLoading: false);
        return;
      }

      logInfo('Device config loaded: ${deviceConfig.deviceId} (${deviceConfig.mode.name})');

      // Load shop
      final shop = await _isarService.getShop(deviceConfig.shopId);
      
      if (shop == null) {
        logWarning('Shop not found: ${deviceConfig.shopId}');
        state = AuthState(
          deviceConfig: deviceConfig,
          isConfigured: true,
          isLoading: false,
          errorMessage: 'Shop not found',
        );
        return;
      }

      logSuccess('Auth initialized: ${deviceConfig.deviceId} @ ${shop.name}');
      
      state = AuthState(
        deviceConfig: deviceConfig,
        shop: shop,
        isConfigured: true,
        isLoading: false,
      );

      // Check if new day - reset transaction counter
      await _checkAndResetForNewDay();
      
    } catch (e, stack) {
      logError('Failed to initialize auth', error: e, stackTrace: stack);
      state = AuthState(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ==================== ADMIN SETUP ====================

  Future<String?> setupAdminDevice({
    required String deviceId,
    required String shopId,
    required String shopName,
    required int familyDigits,
    required int itemDigits,
  }) async {
    try {
      logInfo('Setting up admin device: $deviceId');
      AppLogger.auth('Admin setup started', details: 'Device: $deviceId, Shop: $shopId');
      
      state = state.copyWith(isLoading: true, errorMessage: null);

      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Check if shop exists
      final existingShop = await _isarService.getShop(shopId);
      
      Shop shop;
      if (existingShop != null) {
        logInfo('Using existing shop: $shopId');
        shop = existingShop;
      } else {
        // Create new shop
        shop = Shop.create(
          shopId: shopId,
          name: shopName,
          familyDigits: familyDigits,
          itemDigits: itemDigits,
          createdAt: DateTime.now(),
          isOpen: true,
          currentShopOpenDate: today,
        );

        await _isarService.saveShop(shop);
        logSuccess('Shop created: $shopId - $shopName');
        AppLogger.database('Shop created', details: 'ID: $shopId, Name: $shopName');
      }

      // Create device config
      final deviceConfig = DeviceConfig.create(
        deviceId: deviceId,
        shopId: shopId,
        mode: DeviceMode.ADMIN,
        isConfigured: true,
        currentTrxCounter: 1,
        currentShopOpenDate: today,
        createdAt: DateTime.now(),
      );

      await _isarService.saveDeviceConfig(deviceConfig);
      logSuccess('Device configured: $deviceId (ADMIN)');
      AppLogger.database('Device config saved', details: 'ID: $deviceId, Mode: ADMIN');

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

      logSuccess('Admin setup completed');
      AppLogger.auth('Admin setup completed', details: 'Device: $deviceId');

      return null; // Success
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

  // ==================== USER SETUP ====================

  Future<String?> setupUserDevice({
    required String deviceId,
    required String shopId,
  }) async {
    try {
      logInfo('Setting up user device: $deviceId');
      AppLogger.auth('User setup started', details: 'Device: $deviceId, Shop: $shopId');
      
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Check if shop exists
      final shop = await _isarService.getShop(shopId);
      
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
      AppLogger.database('Device config saved', details: 'ID: $deviceId, Mode: USER');

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

  // ==================== QUICK DEV SETUP ====================

  Future<String?> quickDevSetup() async {
    try {
      logInfo('Quick dev setup started');
      AppLogger.auth('Quick dev setup started');

      return await setupAdminDevice(
        deviceId: 'ADM001',
        shopId: 'SHOP001',
        shopName: 'Demo Shop (የምሳሌ ሱቅ)',
        familyDigits: 2,
        itemDigits: 4,
      );
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
  }

  int getNextTransactionNumber() {
    return state.deviceConfig?.currentTrxCounter ?? 1;
  }

  // ==================== SHOP OPERATIONS ====================

  Future<void> openShop() async {
    final shop = state.shop;
    final deviceConfig = state.deviceConfig;
    
    if (shop == null || deviceConfig == null) return;
    if (!state.isAdmin) {
      logWarning('Only admin can open shop');
      return;
    }

    try {
      logInfo('Opening shop: ${shop.shopId}');
      
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      await _isarService.updateShopStatus(shop.shopId, true, today);
      
      shop.isOpen = true;
      shop.currentShopOpenDate = today;
      
      // Reset transaction counter for new day if needed
      if (deviceConfig.currentShopOpenDate != today) {
        await _isarService.resetTrxCounterForNewDay(deviceConfig.deviceId, today);
        deviceConfig.currentTrxCounter = 1;
        deviceConfig.currentShopOpenDate = today;
      }
      
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
      
      await _isarService.updateShopStatus(
        shop.shopId,
        false,
        shop.currentShopOpenDate,
      );
      
      shop.isOpen = false;
      state = state.copyWith(shop: shop);
      
      logSuccess('Shop closed');
      AppLogger.business('Shop closed', details: shop.name);
    } catch (e, stack) {
      logError('Failed to close shop', error: e, stackTrace: stack);
    }
  }

  // ==================== DAY MANAGEMENT ====================

  Future<void> _checkAndResetForNewDay() async {
    final deviceConfig = state.deviceConfig;
    if (deviceConfig == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    
    if (deviceConfig.currentShopOpenDate != today) {
      logInfo('New day detected, resetting transaction counter');
      
      await _isarService.resetTrxCounterForNewDay(deviceConfig.deviceId, today);
      
      deviceConfig.currentTrxCounter = 1;
      deviceConfig.currentShopOpenDate = today;
      
      state = state.copyWith(deviceConfig: deviceConfig);
      
      logSuccess('Reset for new day: $today');
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