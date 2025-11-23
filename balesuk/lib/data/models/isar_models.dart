// lib/data/models/isar_models.dart

import 'package:isar/isar.dart';
import '../../core/utils/money.dart';

part 'isar_models.g.dart';

// ==================== ENUMS ====================

enum DeviceMode { ADMIN, USER }
enum TransactionStatus { DUBE, COMPLETED }
enum AttributeDataType { TEXT, NUMBER, DATE, BOOLEAN, DROPDOWN }
enum SyncStatus {
  SUCCESS,
  FAILED_UNKNOWN_ITEM,
  FAILED_PRICE_MISMATCH,
  FAILED_OTHER
}

// ==================== DEVICE CONFIG ====================

@collection
class DeviceConfig {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String deviceId;

  late String shopId;
  
  @Enumerated(EnumType.name)
  late DeviceMode mode;
  
  late bool isConfigured;
  late int currentTrxCounter;
  late String currentShopOpenDate;
  late DateTime createdAt;

  DeviceConfig();

  DeviceConfig.create({
    required this.deviceId,
    required this.shopId,
    required this.mode,
    required this.isConfigured,
    required this.currentTrxCounter,
    required this.currentShopOpenDate,
    required this.createdAt,
  });
}

// ==================== SHOP ====================

@collection
class Shop {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String shopId;

  late String name;
  late int? familyDigits;
  late int? itemDigits;
  
  late DateTime createdAt;
  late bool isOpen;
  late String currentShopOpenDate;

  Shop();

  Shop.create({
    required this.shopId,
    required this.name,
    this.familyDigits,
    this.itemDigits,
    required this.createdAt,
    required this.isOpen,
    required this.currentShopOpenDate,
  });
}

// ==================== ITEM FAMILY ====================

@collection
class ItemFamily {
  Id id = Isar.autoIncrement;

  // INTEGER storage for fast queries ⭐
  @Index(unique: true)
  late int familyCode;

  @Index()
  late String shopId;

  late String name;
  String? description;
  late DateTime createdAt;
  
  // Track current max sequence for O(1) ID generation ⭐
  late int currentMaxSequence;

  ItemFamily();

  ItemFamily.create({
    required this.familyCode,
    required this.shopId,
    required this.name,
    this.description,
    required this.createdAt,
  }) : currentMaxSequence = 0;

  // STRING getter (formatted with leading zeros) ⭐
  @ignore
  String get familyId => familyCode.toString().padLeft(2, '0');
  
  // Setter from string
  set familyId(String value) {
    familyCode = int.parse(value);
  }
}

// ==================== ITEM ====================

@collection
class Item {
  Id id = Isar.autoIncrement;

  // INTEGER storage for fast queries ⭐
  @Index(unique: true)
  late int itemCode;

  @Index()
  late int familyCode;

  @Index()
  late String shopId;

  late String name;
  late double price;
  late int quantity;
  late int minQuantity;
  late bool isActive;
  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? lastSoldAt;

  // Soft delete fields
  late bool isDeleted;
  DateTime? deletedAt;

  Item();

  Item.create({
    required this.itemCode,
    required this.familyCode,
    required this.shopId,
    required this.name,
    required Money priceValue,
    required this.quantity,
    required this.minQuantity,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  }) : price = priceValue.amount,
       isDeleted = false;

  // STRING getters (formatted with leading zeros) ⭐
  @ignore
  String get itemId => itemCode.toString().padLeft(6, '0');
  
  @ignore
  String get familyId => familyCode.toString().padLeft(2, '0');
  
  @ignore
  String get barcodeId => itemId;  // Alias for barcode
  
  // Setters from string
  set itemId(String value) {
    itemCode = int.parse(value);
  }
  
  set familyId(String value) {
    familyCode = int.parse(value);
  }

  // Computed properties
  @ignore
  bool get isLowStock => quantity <= minQuantity && isActive;
  
  @ignore
  bool get hasStock => quantity > 0;
  
  @ignore
  Money get priceAsMoney => Money.fromDouble(price);
  
  set priceAsMoney(Money value) {
    price = value.amount;
  }
  
  @ignore
  Money get inventoryValue => priceAsMoney * quantity;

  @ignore
  bool get canBeSoftDeleted {
    return quantity == 0 && !isActive && !isDeleted;
  }
}

// ==================== ATTRIBUTE DEFINITION ====================

@collection
class AttributeDefinition {
  Id id = Isar.autoIncrement;

  @Index()
  late int familyCode;  // ⭐ Changed to int

  late String name;
  
  @Enumerated(EnumType.name)
  late AttributeDataType dataType;
  
  late bool isRequired;
  List<String>? dropdownOptions;
  late int displayOrder;
  late DateTime createdAt;

  AttributeDefinition();

  AttributeDefinition.create({
    required this.familyCode,
    required this.name,
    required this.dataType,
    required this.isRequired,
    this.dropdownOptions,
    required this.displayOrder,
    required this.createdAt,
  });

  // STRING getter
  @ignore
  String get familyId => familyCode.toString().padLeft(2, '0');
  
  set familyId(String value) {
    familyCode = int.parse(value);
  }
}

// ==================== ITEM ATTRIBUTE ====================

@collection
class ItemAttribute {
  Id id = Isar.autoIncrement;

  @Index()
  late int itemCode;  // ⭐ Changed to int

  late int attributeDefinitionId;
  
  String? valueText;
  double? valueNumber;
  String? valueDate;
  bool? valueBoolean;
  
  late DateTime createdAt;
  late DateTime updatedAt;

  ItemAttribute();

  ItemAttribute.create({
    required this.itemCode,
    required this.attributeDefinitionId,
    this.valueText,
    this.valueNumber,
    this.valueDate,
    this.valueBoolean,
    required this.createdAt,
    required this.updatedAt,
  });

  // STRING getter
  @ignore
  String get itemId => itemCode.toString().padLeft(6, '0');
  
  set itemId(String value) {
    itemCode = int.parse(value);
  }
}

// ==================== TRANSACTION ====================

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String transactionId;

  @Index()
  late String deviceId;

  late String shopId;

  @Enumerated(EnumType.name)
  late TransactionStatus status;

  String? customerName;
  String? customerPhone;
  
  late double totalAmount;
  late double totalDiscount;
  
  late DateTime createdAt;

  @Index()
  late String shopOpenDate;

  late bool isSynced;
  DateTime? syncedAt;

  Transaction();

  Transaction.create({
    required this.transactionId,
    required this.deviceId,
    required this.shopId,
    required this.status,
    this.customerName,
    this.customerPhone,
    required Money totalAmountValue,
    required Money totalDiscountValue,
    required this.createdAt,
    required this.shopOpenDate,
    required this.isSynced,
    this.syncedAt,
  }) : totalAmount = totalAmountValue.amount,
       totalDiscount = totalDiscountValue.amount;

  @ignore
  Money get totalAsMoney => Money.fromDouble(totalAmount);
  
  set totalAsMoney(Money value) {
    totalAmount = value.amount;
  }

  @ignore
  Money get totalDiscountAsMoney => Money.fromDouble(totalDiscount);
  
  set totalDiscountAsMoney(Money value) {
    totalDiscount = value.amount;
  }
}

// ==================== TRANSACTION LINE ====================

@collection
class TransactionLine {
  Id id = Isar.autoIncrement;

  @Index()
  late String transactionId;

  late int lineNumber;
  
  // INTEGER storage for item reference ⭐
  late int itemCode;
  
  String? itemName;
  late int quantity;
  
  late double originalPrice;
  late double discount;
  late double unitPrice;
  late double lineTotal;
  
  late DateTime createdAt;

  TransactionLine();

  TransactionLine.create({
    required this.transactionId,
    required this.lineNumber,
    required this.itemCode,
    this.itemName,
    required this.quantity,
    required Money originalPriceValue,
    required Money discountValue,
    required Money unitPriceValue,
    required Money lineTotalValue,
    required this.createdAt,
  }) : originalPrice = originalPriceValue.amount,
       discount = discountValue.amount,
       unitPrice = unitPriceValue.amount,
       lineTotal = lineTotalValue.amount;

  // STRING getter for display ⭐
  @ignore
  String get itemId => itemCode.toString().padLeft(6, '0');
  
  set itemId(String value) {
    itemCode = int.parse(value);
  }

  @ignore
  Money get originalPriceAsMoney => Money.fromDouble(originalPrice);
  
  @ignore
  Money get discountAsMoney => Money.fromDouble(discount);
  
  @ignore
  Money get unitPriceAsMoney => Money.fromDouble(unitPrice);
  
  @ignore
  Money get lineTotalAsMoney => Money.fromDouble(lineTotal);

  @ignore
  double get discountPercentage => 
    originalPrice > 0 ? (discount / originalPrice * 100) : 0.0;
}

// ==================== SYNC HISTORY ====================

@collection
class SyncHistory {
  Id id = Isar.autoIncrement;

  @Index()
  late String fromDeviceId;

  late String toDeviceId;
  late DateTime dateTime;
  
  @Enumerated(EnumType.name)
  late SyncStatus status;
  
  late int transactionsCount;
  String? details;

  SyncHistory();

  SyncHistory.create({
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.dateTime,
    required this.status,
    required this.transactionsCount,
    this.details,
  });
}

// ==================== PRICE HISTORY ====================

@collection
class PriceHistory {
  Id id = Isar.autoIncrement;

  @Index()
  late int itemCode;  // ⭐ Changed to int

  late double oldPrice;
  late double newPrice;
  late DateTime changedAt;
  late String changedBy;

  PriceHistory();

  PriceHistory.create({
    required this.itemCode,
    required Money oldPriceValue,
    required Money newPriceValue,
    required this.changedAt,
    required this.changedBy,
  }) : oldPrice = oldPriceValue.amount,
       newPrice = newPriceValue.amount;

  @ignore
  Money get oldPriceAsMoney => Money.fromDouble(oldPrice);
  
  @ignore
  Money get newPriceAsMoney => Money.fromDouble(newPrice);

  // STRING getter
  @ignore
  String get itemId => itemCode.toString().padLeft(6, '0');
  
  set itemId(String value) {
    itemCode = int.parse(value);
  }
}
// ==================== SEQUENCE ====================

@collection
class Sequence {
  /// The unique key for the sequence record (e.g., 'family', 'item').
  final Id key; 

  /// The shopId is part of the ID for unique tracking per location.
  @Index(unique: true)
  final String shopId;

  /// The current value of the sequence number.
  int value;

  Sequence({
    required this.key,
    required this.shopId,
    this.value = 0,
  });
}