import '../../../core/utils/money.dart';

class CreateFamilyDto {
  final String shopId;
  final String name;
  final String? description;
  final int familyDigits;

  CreateFamilyDto({
    required this.shopId,
    required this.name,
    this.description,
    required this.familyDigits,
  });
}

class CreateItemDto {
  final String familyId;
  final String shopId;
  final String name;
  final Money price;
  final int quantity;
  final int minQuantity;
  final int familyDigits;
  final int itemDigits;
  final Map<int, dynamic>? attributeValues;

  CreateItemDto({
    required this.familyId,
    required this.shopId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.minQuantity,
    required this.familyDigits,
    required this.itemDigits,
    this.attributeValues,
  });

  int get familyCode => int.parse(familyId);
}

class UpdateItemDto {
  final String? name;
  final Money? price;
  final int? quantity;
  final int? minQuantity;
  final bool? isActive;

  UpdateItemDto({
    this.name,
    this.price,
    this.quantity,
    this.minQuantity,
    this.isActive,
  });

  bool get hasUpdates =>
      name != null ||
      price != null ||
      quantity != null ||
      minQuantity != null ||
      isActive != null;
}

class BulkCreateItemsDto {
  final String familyId;
  final String shopId;
  final List<ItemData> items;
  final int familyDigits;
  final int itemDigits;

  BulkCreateItemsDto({
    required this.familyId,
    required this.shopId,
    required this.items,
    required this.familyDigits,
    required this.itemDigits,
  });
  int get familyCode => int.parse(familyId);
}

class ItemData {
  final String name;
  final Money price;
  final int quantity;
  final int minQuantity;

  ItemData({
    required this.name,
    required this.price,
    required this.quantity,
    required this.minQuantity,
  });

  factory ItemData.fromJson(Map<String, dynamic> json) {
    // 1. Validate and cast the raw price value (which is a double in the map)
    final double rawPrice = json['price'] as double;

    return ItemData(
      name: json['name'] as String,
      
      // 2. Use the Money.fromJson factory to create the Money object
      price: Money.fromJson(rawPrice), 
      
      quantity: json['quantity'] as int,
      minQuantity: json['minQuantity'] as int,
    );
  }

  // Optional: Convert ItemData back to a Map for storage/API
  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price.toJson(), // Uses the Money.toJson() method
    'quantity': quantity,
    'minQuantity': minQuantity,
  };
}
