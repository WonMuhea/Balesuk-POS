enum TransactionStatus { DUBE, COMPLETED }

class Transaction {
  final String transactionId;
  final String deviceId;
  final String shopId;
  TransactionStatus status;
  String? customerName;
  String? customerPhone;
  double totalAmount;
  final DateTime createdAt;
  final String shopOpenDate;
  bool isSynced;
  DateTime? syncedAt;

  Transaction({
    required this.transactionId,
    required this.deviceId,
    required this.shopId,
    required this.status,
    this.customerName,
    this.customerPhone,
    required this.totalAmount,
    required this.createdAt,
    required this.shopOpenDate,
    required this.isSynced,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'deviceId': deviceId,
      'shopId': shopId,
      'status': status.name,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'totalAmount': totalAmount,
      'createdAt': createdAt.toIso8601String(),
      'shopOpenDate': shopOpenDate,
      'isSynced': isSynced ? 1 : 0,
      'syncedAt': syncedAt?.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      transactionId: map['transactionId'] as String,
      deviceId: map['deviceId'] as String,
      shopId: map['shopId'] as String,
      status: TransactionStatus.values.byName(map['status'] as String),
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      shopOpenDate: map['shopOpenDate'] as String,
      isSynced: (map['isSynced'] as int) == 1,
      syncedAt: map['syncedAt'] != null 
          ? DateTime.parse(map['syncedAt'] as String) 
          : null,
    );
  }

  Transaction copyWith({
    TransactionStatus? status,
    String? customerName,
    String? customerPhone,
    double? totalAmount,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return Transaction(
      transactionId: transactionId,
      deviceId: deviceId,
      shopId: shopId,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt,
      shopOpenDate: shopOpenDate,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

class TransactionLine {
  final int? id;
  final String transactionId;
  final String itemId;
  int quantity;
  double unitPrice;
  double lineTotal;
  final DateTime createdAt;

  TransactionLine({
    this.id,
    required this.transactionId,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transactionId': transactionId,
      'itemId': itemId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TransactionLine.fromMap(Map<String, dynamic> map) {
    return TransactionLine(
      id: map['id'] as int?,
      transactionId: map['transactionId'] as String,
      itemId: map['itemId'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      lineTotal: (map['lineTotal'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  TransactionLine copyWith({
    int? quantity,
    double? unitPrice,
  }) {
    final newQuantity = quantity ?? this.quantity;
    final newUnitPrice = unitPrice ?? this.unitPrice;
    return TransactionLine(
      id: id,
      transactionId: transactionId,
      itemId: itemId,
      quantity: newQuantity,
      unitPrice: newUnitPrice,
      lineTotal: newQuantity * newUnitPrice,
      createdAt: createdAt,
    );
  }
}