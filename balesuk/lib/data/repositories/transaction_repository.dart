/* // lib/data/repositories/transaction_repository_integer.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/isar_service.dart';
import '../models/isar_models.dart';
import '../../core/utils/money.dart';
import '../../core/helpers/id_generator.dart';
import '../../core/providers/providers.dart';

// ==================== PROVIDER ====================

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return TransactionRepository(isarService);
});

// ==================== DTOs ====================

class CreateTransactionDTO {
  final String deviceId;
  final String shopId;
  final String? customerName;
  final String? customerPhone;
  final String shopOpenDate;
  final List<TransactionLineDTO> lines;

  CreateTransactionDTO({
    required this.deviceId,
    required this.shopId,
    this.customerName,
    this.customerPhone,
    required this.shopOpenDate,
    required this.lines,
  });

  Money get totalAmount {
    return lines.fold(Money.zero(), (sum, line) => sum + line.lineTotal);
  }

  Money get totalDiscount {
    return lines.fold(Money.zero(), (sum, line) => sum + line.discount);
  }
}

class TransactionLineDTO {
  final int itemCode;           // ⭐ Store as integer
  final String? itemName;
  final int quantity;
  final Money originalPrice;
  final Money discount;
  final Money unitPrice;
  final Money lineTotal;

  TransactionLineDTO({
    required this.itemCode,
    this.itemName,
    required this.quantity,
    required this.originalPrice,
    required this.discount,
    required this.unitPrice,
    required this.lineTotal,
  });

  // STRING getter for display
  String get itemId => itemCode.toString().padLeft(6, '0');

  /// Create from item with optional discount
  factory TransactionLineDTO.fromItem({
    required Item item,
    required int quantity,
    Money? discountAmount,
  }) {
    final originalPrice = item.priceAsMoney;
    final discount = discountAmount ?? Money.zero();
    final unitPrice = originalPrice - discount;
    final lineTotal = unitPrice * quantity;

    return TransactionLineDTO(
      itemCode: item.itemCode,      // ⭐ Use integer
      itemName: item.name,
      quantity: quantity,
      originalPrice: originalPrice,
      discount: discount,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
    );
  }

  /// Create manual entry (USER mode)
  factory TransactionLineDTO.manual({
    required int itemCode,          // ⭐ Accept integer
    required String itemName,
    required int quantity,
    required Money unitPrice,
  }) {
    return TransactionLineDTO(
      itemCode: itemCode,
      itemName: itemName,
      quantity: quantity,
      originalPrice: unitPrice,
      discount: Money.zero(),
      unitPrice: unitPrice,
      lineTotal: unitPrice * quantity,
    );
  }

  /// Create from scanned barcode
  factory TransactionLineDTO.fromBarcode({
    required String barcode,
    required Item item,
    required int quantity,
    Money? discountAmount,
  }) {
    // Parse barcode to code (validation)
    final scannedCode = IdGenerator.parseBarcodeToItemCode(barcode);
    
    if (scannedCode != item.itemCode) {
      throw Exception('Barcode mismatch: scanned $scannedCode but item is ${item.itemCode}');
    }
    
    return TransactionLineDTO.fromItem(
      item: item,
      quantity: quantity,
      discountAmount: discountAmount,
    );
  }

  TransactionLineDTO withDiscount(Money discountAmount) {
    final newUnitPrice = originalPrice - discountAmount;
    final newLineTotal = newUnitPrice * quantity;

    return TransactionLineDTO(
      itemCode: itemCode,
      itemName: itemName,
      quantity: quantity,
      originalPrice: originalPrice,
      discount: discountAmount,
      unitPrice: newUnitPrice,
      lineTotal: newLineTotal,
    );
  }

  double get discountPercentage {
    if (originalPrice.amount <= 0) return 0.0;
    return (discount.amount / originalPrice.amount) * 100;
  }
}

// ==================== REPOSITORY ====================

class TransactionRepository {
  final IsarService _isarService;

  TransactionRepository(this._isarService);

  /// Create a new transaction with lines
  Future<Transaction> createTransaction({
    required CreateTransactionDTO dto,
  }) async {
    final numberOfTransactions = await _isarService.countTodayTransactions(dto.deviceId, dto.shopOpenDate);
    final counter = numberOfTransactions + 1;

    // Generate transaction ID with date
    final date = DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
    final transactionId = IdGenerator.generateTransactionId(
      deviceId: dto.deviceId,
      date: date,
      trxCounter: counter,
    );

    final totalAmount = dto.totalAmount;
    final totalDiscount = dto.totalDiscount;

    // Create transaction
    final transaction = Transaction.create(
      transactionId: transactionId,
      deviceId: dto.deviceId,
      shopId: dto.shopId,
      status: TransactionStatus.DUBE,
      customerName: dto.customerName,
      customerPhone: dto.customerPhone,
      totalAmountValue: totalAmount,
      totalDiscountValue: totalDiscount,
      createdAt: DateTime.now(),
      shopOpenDate: dto.shopOpenDate,
      isSynced: false,
    );

    // Create transaction lines with INTEGER item codes ⭐
    final lines = <TransactionLine>[];
    for (int i = 0; i < dto.lines.length; i++) {
      final lineDTO = dto.lines[i];
      
      final line = TransactionLine.create(
        transactionId: transactionId,
        lineNumber: i + 1,
        itemCode: lineDTO.itemCode,       // ⭐ Store as integer!
        itemName: lineDTO.itemName,
        quantity: lineDTO.quantity,
        originalPriceValue: lineDTO.originalPrice,
        discountValue: lineDTO.discount,
        unitPriceValue: lineDTO.unitPrice,
        lineTotalValue: lineDTO.lineTotal,
        createdAt: DateTime.now(),
      );
      
      lines.add(line);
    }

    // Save transaction and lines
    await _isarService.saveTransaction(transaction);
    await _isarService.saveMultipleTransactionLines(lines);

    // Update item lastSoldAt dates (using integer codes) ⭐
    for (final lineDTO in dto.lines) {
      await _updateLastSoldDate(lineDTO.itemCode);
    }

    return transaction;
  }

  /// Update last sold date for an item (using integer code)
  Future<void> _updateLastSoldDate(int itemCode) async {
    final item = await _isarService.getItemByCode(itemCode);  // ⭐ Integer query
  
    if (item != null) {
        item.lastSoldAt = DateTime.now();
        await _isarService.save/*  */Item(item);
    }
  }

  /// Complete a transaction
  Future<void> completeTransaction(String transactionId) async {
    final transaction = await _isarService.getTransaction(transactionId);
    if (transaction == null) {
      throw Exception('Transaction not found: $transactionId');
    }

    transaction.status = TransactionStatus.COMPLETED;
    await _isarService.saveTransaction(transaction);
  }

  /// Add customer info to transaction
  Future<void> updateCustomerInfo({
    required String transactionId,
    String? customerName,
    String? customerPhone,
  }) async {
    final transaction = await _isarService.getTransaction(transactionId);
    if (transaction == null) {
      throw Exception('Transaction not found: $transactionId');
    }

    transaction.customerName = customerName;
    transaction.customerPhone = customerPhone;
    await _isarService.saveTransaction(transaction);
  }

  /// Add a line to existing transaction
  Future<void> addTransactionLine({
    required String transactionId,
    required TransactionLineDTO lineDTO,
  }) async {
    final existingLines = await _isarService.getTransactionLines(transactionId);
    final nextLineNumber = existingLines.length + 1;

    final line = TransactionLine.create(
      transactionId: transactionId,
      lineNumber: nextLineNumber,
      itemCode: lineDTO.itemCode,       // ⭐ Integer storage
      itemName: lineDTO.itemName,
      quantity: lineDTO.quantity,
      originalPriceValue: lineDTO.originalPrice,
      discountValue: lineDTO.discount,
      unitPriceValue: lineDTO.unitPrice,
      lineTotalValue: lineDTO.lineTotal,
      createdAt: DateTime.now(),
    );

    await _isarService.saveTransactionLine(line);
    await _recalculateTransactionTotal(transactionId);
    await _updateLastSoldDate(lineDTO.itemCode);
  }

  /// Remove a line from transaction
  Future<void> removeTransactionLine({
    required String transactionId,
    required int lineId,
  }) async {
    await _isarService.deleteTransactionLine(lineId);
    await _recalculateTransactionTotal(transactionId);
    await _renumberTransactionLines(transactionId);
  }

  /// Update line quantity
  Future<void> updateLineQuantity({
    required String transactionId,
    required int lineId,
    required int newQuantity,
  }) async {
    final lines = await _isarService.getTransactionLines(transactionId);
    final line = lines.firstWhere((l) => l.id == lineId);

    final newLineTotal = line.unitPriceAsMoney * newQuantity;
    line.quantity = newQuantity;
    line.lineTotal = newLineTotal.amount;

    await _isarService.saveTransactionLine(line);
    await _recalculateTransactionTotal(transactionId);
  }

  /// Apply discount to a line
  Future<void> applyLineDiscount({
    required String transactionId,
    required int lineId,
    required Money discountAmount,
  }) async {
    final lines = await _isarService.getTransactionLines(transactionId);
    final line = lines.firstWhere((l) => l.id == lineId);

    final originalPrice = line.originalPriceAsMoney;
    final newUnitPrice = originalPrice - discountAmount;
    final newLineTotal = newUnitPrice * line.quantity;

    line.discount = discountAmount.amount;
    line.unitPrice = newUnitPrice.amount;
    line.lineTotal = newLineTotal.amount;

    await _isarService.saveTransactionLine(line);
    await _recalculateTransactionTotal(transactionId);
  }

  /// Recalculate transaction total from lines
  Future<void> _recalculateTransactionTotal(String transactionId) async {
    final transaction = await _isarService.getTransaction(transactionId);
    if (transaction == null) return;

    final lines = await _isarService.getTransactionLines(transactionId);

    Money totalAmount = Money.zero();
    Money totalDiscount = Money.zero();

    for (final line in lines) {
      totalAmount = totalAmount + line.lineTotalAsMoney;
      totalDiscount = totalDiscount + line.discountAsMoney;
    }

    transaction.totalAmount = totalAmount.amount;
    transaction.totalDiscount = totalDiscount.amount;
    await _isarService.saveTransaction(transaction);
  }

  /// Renumber lines after deletion
  Future<void> _renumberTransactionLines(String transactionId) async {
    final lines = await _isarService.getTransactionLines(transactionId);
    lines.sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

    for (int i = 0; i < lines.length; i++) {
      lines[i].lineNumber = i + 1;
    }

    await _isarService.saveMultipleTransactionLines(lines);
  }

  // ==================== QUERIES ====================

  Future<Transaction?> getTransaction(String transactionId) async {
    return await _isarService.getTransaction(transactionId);
  }

  Future<List<TransactionLine>> getTransactionLines(String transactionId) async {
    return await _isarService.getTransactionLines(transactionId);
  }

  Future<List<Transaction>> getTodayTransactions({
    required String deviceId,
    required String date,
  }) async {
    return await _isarService.getTodayTransactions(deviceId, date);
  }

  Stream<List<Transaction>> watchTodayTransactions({
    required String deviceId,
    required String date,
  }) {
    return _isarService.watchTodayTransactions(deviceId, date);
  }

  Future<List<Transaction>> getUnsyncedTransactions(String deviceId) async {
    return await _isarService.getUnsyncedTransactions(deviceId);
  }

  Future<List<Transaction>> getTransactionsByDateRange({
    required String shopId,
    required String startDate,
    required String endDate,
  }) async {
    return await _isarService.getTransactionsByDateRange(
      shopId: shopId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> markTransactionsSynced(List<String> transactionIds) async {
    await _isarService.markTransactionsSynced(transactionIds);
  }

  // ==================== ANALYTICS ====================

  Future<TransactionStats> getTransactionStats({
    required String deviceId,
    required String date,
  }) async {
    final transactions = await getTodayTransactions(
      deviceId: deviceId,
      date: date,
    );

    Money totalSales = Money.zero();
    Money totalDiscounts = Money.zero();
    int totalItems = 0;
    int completedCount = 0;

    for (final txn in transactions) {
      totalSales = totalSales + txn.totalAsMoney;
      totalDiscounts = totalDiscounts + txn.totalDiscountAsMoney;
      
      if (txn.status == TransactionStatus.COMPLETED) {
        completedCount++;
      }

      final lines = await getTransactionLines(txn.transactionId);
      totalItems += lines.fold<int>(0, (sum, line) => sum + line.quantity);
    }

    return TransactionStats(
      totalTransactions: transactions.length,
      completedTransactions: completedCount,
      totalSales: totalSales,
      totalDiscounts: totalDiscounts,
      totalItems: totalItems,
      averageTransactionValue: transactions.isEmpty 
          ? Money.zero()
          : totalSales / transactions.length.toDouble(),
    );
  }

  Future<List<ItemSalesStats>> getBestSellingItems({
    required String shopId,
    required String startDate,
    required String endDate,
    int limit = 10,
  }) async {
    final transactions = await getTransactionsByDateRange(
      shopId: shopId,
      startDate: startDate,
      endDate: endDate,
    );

    // Collect item sales data (using integer codes) ⭐
    final Map<int, ItemSalesData> itemSalesMap = {};

    for (final txn in transactions) {
      final lines = await getTransactionLines(txn.transactionId);
      
      for (final line in lines) {
        if (!itemSalesMap.containsKey(line.itemCode)) {  // ⭐ Integer key!
          itemSalesMap[line.itemCode] = ItemSalesData(
            itemCode: line.itemCode,                     // ⭐ Integer storage
            itemName: line.itemName ?? 'Unknown',
            quantity: 0,
            revenue: Money.zero(),
            discount: Money.zero(),
          );
        }

        final data = itemSalesMap[line.itemCode]!;
        data.quantity += line.quantity;
        data.revenue = data.revenue + line.lineTotalAsMoney;
        data.discount = data.discount + line.discountAsMoney;
      }
    }

    final stats = itemSalesMap.values
        .map((data) => ItemSalesStats(
              itemCode: data.itemCode,               // ⭐ Integer
              itemName: data.itemName,
              quantitySold: data.quantity,
              totalRevenue: data.revenue,
              totalDiscount: data.discount,
            ))
        .toList();

    stats.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    return stats.take(limit).toList();
  }
}

// ==================== STATS CLASSES ====================

class TransactionStats {
  final int totalTransactions;
  final int completedTransactions;
  final Money totalSales;
  final Money totalDiscounts;
  final int totalItems;
  final Money averageTransactionValue;

  TransactionStats({
    required this.totalTransactions,
    required this.completedTransactions,
    required this.totalSales,
    required this.totalDiscounts,
    required this.totalItems,
    required this.averageTransactionValue,
  });

  Money get netSales => totalSales - totalDiscounts;
}

class ItemSalesStats {
  final int itemCode;             // ⭐ Integer storage
  final String itemName;
  final int quantitySold;
  final Money totalRevenue;
  final Money totalDiscount;

  ItemSalesStats({
    required this.itemCode,
    required this.itemName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalDiscount,
  });

  // STRING getter for display
  String get itemId => itemCode.toString().padLeft(6, '0');

  Money get netRevenue => totalRevenue - totalDiscount;
}

class ItemSalesData {
  final int itemCode;             // ⭐ Integer storage
  final String itemName;
  int quantity;
  Money revenue;
  Money discount;

  ItemSalesData({
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.revenue,
    required this.discount,
  });
} */