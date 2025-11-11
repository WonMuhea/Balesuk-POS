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

  Item();

  Item.create({
    required this.itemId,
    required this.familyId,
    required this.shopId,
    required this.name,
    required Money priceValue, // Accept Money
    required this.quantity,
    required this.minQuantity,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  }) : price = priceValue.amount; // Store as double

  // Computed properties - @ignore tells Isar not to persist these
  @ignore
  bool get isLowStock => quantity <= minQuantity && isActive;
  
  @ignore
  bool get hasStock => quantity > 0;
  
  // Money getter for price
  @ignore
  Money get priceAsMoney => Money.fromDouble(price);
  
  // Money setter for price
  set priceAsMoney(Money value) {
    price = value.amount;
  }
  
  // Calculate total inventory value
  @ignore
  Money get inventoryValue => priceAsMoney * quantity;
}

// ==================== TRANSACTION ====================

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String transactionId;

  @Index()
  late String deviceId;

  @Index()
  late String shopId;

  @Enumerated(EnumType.name)
  late TransactionStatus status;

  String? customerName;
  String? customerPhone;
  
  // Store totalAmount as double, use Money for operations
  late double totalAmount;
  
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
    required Money totalAmountValue, // Accept Money
    required this.createdAt,
    required this.shopOpenDate,
    required this.isSynced,
    this.syncedAt,
  }) : totalAmount = totalAmountValue.amount; // Store as double

  // Money getter
  @ignore
  Money get totalAsMoney => Money.fromDouble(totalAmount);
  
  // Money setter
  set totalAsMoney(Money value) {
    totalAmount = value.amount;
  }
}

// ==================== TRANSACTION LINE ====================

@collection
class TransactionLine {
  Id id = Isar.autoIncrement;

  @Index()
  late String transactionId;

  late String itemId;
  late int quantity;
  
  // Store prices as double, use Money for operations
  late double unitPrice;
  late double lineTotal;
  
  late DateTime createdAt;

  TransactionLine();

  TransactionLine.create({
    required this.transactionId,
    required this.itemId,
    required this.quantity,
    required Money unitPriceValue, // Accept Money
    required Money lineTotalValue, // Accept Money
    required this.createdAt,
  }) : unitPrice = unitPriceValue.amount,
       lineTotal = lineTotalValue.amount;

  // Money getters
  @ignore
  Money get unitPriceAsMoney => Money.fromDouble(unitPrice);
  
  @ignore
  Money get lineTotalAsMoney => Money.fromDouble(lineTotal);
  
  // Money setters
  set unitPriceAsMoney(Money value) {
    unitPrice = value.amount;
  }
  
  set lineTotalAsMoney(Money value) {
    lineTotal = value.amount;
  }
  
  // Calculate line total from quantity and unit price
  Money calculateLineTotal() {
    return unitPriceAsMoney * quantity;
  }
  
  // Update line total based on quantity and unit price
  void updateLineTotal() {
    lineTotalAsMoney = calculateLineTotal();
  }
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
    required Money oldPriceValue, // Accept Money
    required Money newPriceValue, // Accept Money
    required this.changedAt,
    required this.changedBy,
  }) : oldPrice = oldPriceValue.amount,
       newPrice = newPriceValue.amount;

  // Money getters
  @ignore
  Money get oldPriceAsMoney => Money.fromDouble(oldPrice);
  
  @ignore
  Money get newPriceAsMoney => Money.fromDouble(newPrice);
  
  // Calculate price difference
  @ignore
  Money get priceDifference => newPriceAsMoney - oldPriceAsMoney;
  
  // Calculate percentage change
  @ignore
  double get percentageChange {
    if (oldPrice == 0) return 0;
    return ((newPrice - oldPrice) / oldPrice) * 100;
  }
}

// ==================== OTHER COLLECTIONS (unchanged) ====================

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