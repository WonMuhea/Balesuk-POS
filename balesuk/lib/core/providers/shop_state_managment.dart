import 'package:balesuk/features/inventory/services/configuration_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/isar_models.dart';

// ... (rest of the ShopNotifier class definition)

class ShopNotifier extends AsyncNotifier<Shop?> {
  
  // Internal dependencies
  late final ShopConfigurationService _shopService;
  
  @override
  Future<Shop?> build() async {
    _shopService = ref.read(shopConfigurationServiceProvider);
    return null; 
  }

  Future<void> getShop(String shopId) async {
    // 1. Start Loading State
    state = const AsyncLoading();

    final result = await _shopService.openShop(shopId);

    // 3. Process the Result and Update Global State
    state = await result.when(
      success: (shop) {
        return AsyncValue.data(shop);
      },
      error: (failure) {
        // Error: Propagate the failure object to the state.
        return AsyncValue.error(failure, StackTrace.current);
      },
    );
  }
  
}
