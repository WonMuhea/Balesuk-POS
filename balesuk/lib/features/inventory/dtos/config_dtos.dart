
// ==================== DTOs ====================

import 'package:balesuk/data/models/isar_models.dart';

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
}

 class ShopConfigurationDto {
  final DeviceConfig deviceConfig;
  final Shop shop;

  ShopConfigurationDto({
    required this.deviceConfig,
    required this.shop,
  });
 }
  