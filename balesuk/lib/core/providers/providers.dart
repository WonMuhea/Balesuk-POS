import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/isar_service.dart';
import '../../data/models/isar_models.dart';

// ==================== DATABASE PROVIDER ====================

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService.instance;
});

// ==================== DEVICE CONFIG PROVIDER ====================

final deviceConfigProvider = FutureProvider<DeviceConfig?>((ref) async {
  final isarService = ref.watch(isarServiceProvider);
  final prefs = await SharedPreferences.getInstance();
  final isConfigured = prefs.getBool('isConfigured') ?? false;

  if (!isConfigured) {
    return null;
  }

  return await isarService.getDeviceConfig();
});

// ==================== DEVICE CONFIG NOTIFIER ====================

final deviceConfigNotifierProvider =
    StateNotifierProvider<DeviceConfigNotifier, AsyncValue<DeviceConfig?>>(
  (ref) => DeviceConfigNotifier(ref),
);

class DeviceConfigNotifier extends StateNotifier<AsyncValue<DeviceConfig?>> {
  final Ref _ref;

  DeviceConfigNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  IsarService get _isarService => _ref.read(isarServiceProvider);

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isConfigured = prefs.getBool('isConfigured') ?? false;

      if (!isConfigured) {
        state = const AsyncValue.data(null);
        return;
      }

      final config = await _isarService.getDeviceConfig();
      state = AsyncValue.data(config);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> saveDeviceConfig(DeviceConfig config) async {
    try {
      await _isarService.saveDeviceConfig(config);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isConfigured', true);

      state = AsyncValue.data(config);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateTrxCounter(int newCounter) async {
    final config = state.value;
    if (config == null) return;

    try {
      await _isarService.updateTrxCounter(config.deviceId, newCounter);
      config.currentTrxCounter = newCounter;
      state = AsyncValue.data(config);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> incrementTrxCounter() async {
    final config = state.value;
    if (config == null) return;

    await updateTrxCounter(config.currentTrxCounter + 1);
  }

  Future<void> resetForNewDay(String newDate) async {
    final config = state.value;
    if (config == null) return;

    try {
      await _isarService.resetTrxCounterForNewDay(config.deviceId, newDate);
      config.currentTrxCounter = 1;
      config.currentShopOpenDate = newDate;
      state = AsyncValue.data(config);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reload() {
    _loadConfig();
  }
}

// ==================== SHOP PROVIDER ====================

final shopProvider = FutureProvider.family<Shop?, String>((ref, shopId) async {
  final isarService = ref.watch(isarServiceProvider);
  return await isarService.getShop(shopId);
});

final shopNotifierProvider =
    StateNotifierProvider<ShopNotifier, AsyncValue<Shop?>>(
  (ref) => ShopNotifier(ref),
);

class ShopNotifier extends StateNotifier<AsyncValue<Shop?>> {
  final Ref _ref;

  ShopNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadShop();
  }

  IsarService get _isarService => _ref.read(isarServiceProvider);

  Future<void> _loadShop() async {
    try {
      final deviceConfig = _ref.read(deviceConfigProvider).value;
      if (deviceConfig == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final shop = await _isarService.getShop(deviceConfig.shopId);
      state = AsyncValue.data(shop);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> saveShop(Shop shop) async {
    try {
      await _isarService.saveShop(shop);
      state = AsyncValue.data(shop);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> openShop() async {
    final shop = state.value;
    if (shop == null) return;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _isarService.updateShopStatus(shop.shopId, true, today);

      shop.isOpen = true;
      shop.currentShopOpenDate = today;
      state = AsyncValue.data(shop);

      // Also update device config if needed
      final deviceConfig = _ref.read(deviceConfigNotifierProvider).value;
      if (deviceConfig != null && deviceConfig.currentShopOpenDate != today) {
        await _ref
            .read(deviceConfigNotifierProvider.notifier)
            .resetForNewDay(today);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> closeShop() async {
    final shop = state.value;
    if (shop == null) return;

    try {
      await _isarService.updateShopStatus(
          shop.shopId, false, shop.currentShopOpenDate);

      shop.isOpen = false;
      state = AsyncValue.data(shop);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reload() {
    _loadShop();
  }
}

// ==================== INVENTORY PROVIDERS ====================

final familiesProvider =
    StreamProvider.family<List<ItemFamily>, String>((ref, shopId) {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.watchAllFamilies(shopId);
});

final itemsProvider = StreamProvider.family<List<Item>, String>((ref, shopId) {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.watchAllItems(shopId);
});

final itemsByFamilyProvider =
    FutureProvider.family<List<Item>, String>((ref, familyId) async {
  final isarService = ref.watch(isarServiceProvider);
  return await isarService.getItemsByFamily(familyId);
});

final itemProvider =
    FutureProvider.family<Item?, String>((ref, itemId) async {
  final isarService = ref.watch(isarServiceProvider);
  return await isarService.getItemById(itemId);
});

final inventoryStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, shopId) async {
  final isarService = ref.watch(isarServiceProvider);
  return await isarService.getInventoryStats(shopId);
});

// ==================== TRANSACTION PROVIDERS ====================

class TransactionParams {
  final String deviceId;
  final String date;

  TransactionParams(this.deviceId, this.date);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionParams &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          date == other.date;

  @override
  int get hashCode => deviceId.hashCode ^ date.hashCode;
}

final todayTransactionsProvider =
    StreamProvider.family<List<Transaction>, TransactionParams>((ref, params) {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.watchTodayTransactions(params.deviceId, params.date);
});

final transactionProvider =
    FutureProvider.family<Transaction?, String>((ref, transactionId) async {
  final isarService = ref.watch(isarServiceProvider);
  return await isarService.getTransaction(transactionId);
});

final transactionLinesProvider =
    FutureProvider.family<List<TransactionLine>, String>(
        (ref, transactionId) async {
  final isarService = ref.watch(isarServiceProvider);
  return await isarService.getTransactionLines(transactionId);
});

// ==================== SYNC PROVIDERS ====================

final syncHistoryProvider = FutureProvider<List<SyncHistory>>((ref) async {
  final isarService = ref.watch(isarServiceProvider);
  return await isarService.getAllSyncHistory();
});