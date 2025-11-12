import 'package:isar/isar.dart';
import '../../core/utils/money.dart';

part 'isar_models.g.dart';

// ==================== ENUMS ====================

enum DeviceMode { ADMIN, USER }
enum TransactionStatus { DUBE, COMPLETED, CANCELLED}
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
  late int familyDigits;
  late int itemDigits;
  
  late DateTime createdAt;
  late bool isOpen;
  late String currentShopOpenDate;

  Shop();

  Shop.create({
    required this.shopId,
    required this.name,
    required this.familyDigits,
    required this.itemDigits,
    required this.createdAt,
    required this.isOpen,
    required this.currentShopOpenDate,
  });
}

// ==================== ITEM FAMILY ====================

@collection
class ItemFamily {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String familyId;

  @Index()
  late String shopId;

  late String name;
  String? description;
  late DateTime createdAt;

  ItemFamily();

  ItemFamily.create({
    required this.familyId,
    required this.shopId,
    required this.name,
    this.description,
    required this.createdAt,
  });
}

// ==================== ITEM ====================

@collection
class Item {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String itemId;

  @Index()
  late String familyId;

  @Index()
  late String shopId;

  late String name;
  
  // Store price as double, but use Money class for operations
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
    required this.itemId,
    required this.familyId,
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

  // Check if can be soft deleted
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
  late String familyId;

  late String name;
  
  @Enumerated(EnumType.name)
  late AttributeDataType dataType;
  
  late bool isRequired;
  List<String>? dropdownOptions;
  late int displayOrder;
  late DateTime createdAt;

  AttributeDefinition();

  AttributeDefinition.create({
    required this.familyId,
    required this.name,
    required this.dataType,
    required this.isRequired,
    this.dropdownOptions,
    required this.displayOrder,
    required this.createdAt,
  });
}

// ==================== ITEM ATTRIBUTE ====================

@collection
class ItemAttribute {
  Id id = Isar.autoIncrement;

  @Index()
  late String itemId;

  late int attributeDefinitionId;
  
  String? valueText;
  double? valueNumber;
  String? valueDate;
  bool? valueBoolean;
  
  late DateTime createdAt;
  late DateTime updatedAt;

  ItemAttribute();

  ItemAttribute.create({
    required this.itemId,
    required this.attributeDefinitionId,
    this.valueText,
    this.valueNumber,
    this.valueDate,
    this.valueBoolean,
    required this.createdAt,
    required this.updatedAt,
  });
}

// ==================== TRANSACTION ====================

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String transactionId;

  @Index()
  late String deviceId;

  late String shopId;  // No index - single shop system

  @Enumerated(EnumType.name)
  late TransactionStatus status;

  String? customerName;
  String? customerPhone;
  
  late double totalAmount;
  late double totalDiscount;  // NEW: Sum of all line discounts
  
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
    required Money totalDiscountValue,  // NEW
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

  late int lineNumber;        // NEW: Line sequence
  late String itemId;
  String? itemName;           // NEW: For USER mode manual entry
  late int quantity;
  
  // Price fields
  late double originalPrice;  // NEW: Tagged/inventory price
  late double discount;       // NEW: Discount amount
  late double unitPrice;      // Final price after discount
  late double lineTotal;      // unitPrice * quantity
  
  late DateTime createdAt;

  TransactionLine();

  TransactionLine.create({
    required this.transactionId,
    required this.lineNumber,
    required this.itemId,
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

  // Money getters
  @ignore
  Money get originalPriceAsMoney => Money.fromDouble(originalPrice);
  
  @ignore
  Money get discountAsMoney => Money.fromDouble(discount);
  
  @ignore
  Money get unitPriceAsMoney => Money.fromDouble(unitPrice);
  
  @ignore
  Money get lineTotalAsMoney => Money.fromDouble(lineTotal);

  // Calculated discount percentage
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
  late String itemId;

  late double oldPrice;
  late double newPrice;
  late DateTime changedAt;
  late String changedBy;

  PriceHistory();

  PriceHistory.create({
    required this.itemId,
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
}