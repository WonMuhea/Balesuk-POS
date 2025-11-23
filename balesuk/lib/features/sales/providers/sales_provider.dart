/* // lib/features/sales/providers/transaction_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/models/isar_models.dart';
import '../../../core/utils/money.dart';
import '../../../core/providers/providers.dart';

// ==================== TRANSACTION STATE ====================

class TransactionState {
  final List<TransactionLineDTO> lines;
  final String? customerName;
  final String? customerPhone;
  final bool isLoading;
  final String? errorMessage;

  TransactionState({
    this.lines = const [],
    this.customerName,
    this.customerPhone,
    this.isLoading = false,
    this.errorMessage,
  });

  TransactionState copyWith({
    List<TransactionLineDTO>? lines,
    String? customerName,
    String? customerPhone,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TransactionState(
      lines: lines ?? this.lines,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Calculate total amount
  Money get totalAmount {
    return lines.fold(
      Money.zero(),
      (sum, line) => sum + line.lineTotal,
    );
  }

  // Calculate total discount
  Money get totalDiscount {
    return lines.fold(
      Money.zero(),
      (sum, line) => sum + line.discount,
    );
  }

  // Net amount (after discount)
  Money get netAmount => totalAmount;

  // Total items count
  int get totalItems {
    return lines.fold(0, (sum, line) => sum + line.quantity);
  }

  bool get hasLines => lines.isNotEmpty;
}

// ==================== TRANSACTION NOTIFIER ====================

class TransactionNotifier extends StateNotifier<TransactionState> {
  final TransactionRepository _repository;

  TransactionNotifier(this._repository) : super(TransactionState());

  // ==================== ADD/REMOVE LINES ====================

  /// Add a scanned item to transaction
  void addScannedItem(Item item, {int quantity = 1}) {
    final lineDTO = TransactionLineDTO.fromItem(
      item: item,
      quantity: quantity,
    );

    state = state.copyWith(
      lines: [...state.lines, lineDTO],
    );
  }

  /// Add manual item entry (USER mode)
  void addManualItem({
    required String itemId,
    required String itemName,
    required int quantity,
    required Money unitPrice,
  }) {
    final lineDTO = TransactionLineDTO.manual(
      itemCode: int.parse(itemId),
      itemName: itemName,
      quantity: quantity,
      unitPrice: unitPrice,
    );

    state = state.copyWith(
      lines: [...state.lines, lineDTO],
    );
  }

  /// Remove a line by index
  void removeLine(int index) {
    final lines = List<TransactionLineDTO>.from(state.lines);
    lines.removeAt(index);
    state = state.copyWith(lines: lines);
  }

  /// Update line quantity
  void updateLineQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      removeLine(index);
      return;
    }

    final lines = List<TransactionLineDTO>.from(state.lines);
    final line = lines[index];
    
    // Create new line with updated quantity
    final updatedLine = TransactionLineDTO(
      itemCode: int.parse(line.itemId),
      itemName: line.itemName,
      quantity: newQuantity,
      originalPrice: line.originalPrice,
      discount: line.discount,
      unitPrice: line.unitPrice,
      lineTotal: line.unitPrice * newQuantity,
    );

    lines[index] = updatedLine;
    state = state.copyWith(lines: lines);
  }

  /// Apply discount to a line
  void applyLineDiscount(int index, Money discountAmount) {
    final lines = List<TransactionLineDTO>.from(state.lines);
    final line = lines[index];
    
    final updatedLine = line.withDiscount(discountAmount);
    lines[index] = updatedLine;
    state = state.copyWith(lines: lines);
  }

  /// Apply discount percentage to a line
  void applyLineDiscountPercentage(int index, double percentage) {
    if (percentage < 0 || percentage > 100) return;

    final lines = List<TransactionLineDTO>.from(state.lines);
    final line = lines[index];
    
    final discountAmount = line.originalPrice * (percentage / 100);
    final updatedLine = line.withDiscount(discountAmount);
    
    lines[index] = updatedLine;
    state = state.copyWith(lines: lines);
  }

  /// Clear discount from a line
  void clearLineDiscount(int index) {
    applyLineDiscount(index, Money.zero());
  }

  // ==================== CUSTOMER INFO ====================

  void setCustomerName(String? name) {
    state = state.copyWith(customerName: name);
  }

  void setCustomerPhone(String? phone) {
    state = state.copyWith(customerPhone: phone);
  }

  void setCustomerInfo({String? name, String? phone}) {
    state = state.copyWith(
      customerName: name,
      customerPhone: phone,
    );
  }

  // ==================== TRANSACTION OPERATIONS ====================

  /// Create and save transaction
  Future<Transaction?> createTransaction({
    required String deviceId,
    required String shopId,
    required String shopOpenDate,
  }) async {
    if (!state.hasLines) {
      state = state.copyWith(
        errorMessage: 'Cannot create transaction without items',
      );
      return null;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final dto = CreateTransactionDTO(
        deviceId: deviceId,
        shopId: shopId,
        customerName: state.customerName,
        customerPhone: state.customerPhone,
        shopOpenDate: shopOpenDate,
        lines: state.lines,
      );

      final transaction = await _repository.createTransaction(dto: dto);

      // Clear state after successful transaction
      state = TransactionState();

      return transaction;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create transaction: $e',
      );
      return null;
    }
  }

  /// Clear all transaction data
  void clearTransaction() {
    state = TransactionState();
  }

  /// Get line by index
  TransactionLineDTO? getLine(int index) {
    if (index < 0 || index >= state.lines.length) return null;
    return state.lines[index];
  }
}

// ==================== PROVIDERS ====================

/// Current transaction notifier
final transactionNotifierProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return TransactionNotifier(repository);
});

/// Transaction by ID
final transactionProvider =
    FutureProvider.family<Transaction?, String>((ref, transactionId) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return await repository.getTransaction(transactionId);
});

/// Transaction lines by transaction ID
final transactionLinesProvider =
    FutureProvider.family<List<TransactionLine>, String>(
        (ref, transactionId) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return await repository.getTransactionLines(transactionId);
});

/// Today's transactions
final todayTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) async* {
  final deviceConfig = await ref.watch(deviceConfigProvider.future);
  if (deviceConfig == null) {
    yield [];
    return;
  }

  final repository = ref.watch(transactionRepositoryProvider);
  final date = deviceConfig.currentShopOpenDate;

  yield* repository.watchTodayTransactions(
    deviceId: deviceConfig.deviceId,
    date: date,
  );
});

/// Today's transaction stats
final todayStatsProvider = FutureProvider.autoDispose<TransactionStats>((ref) async {
  final deviceConfig = await ref.watch(deviceConfigProvider.future);
  if (deviceConfig == null) {
    return TransactionStats(
      totalTransactions: 0,
      completedTransactions: 0,
      totalSales: Money.zero(),
      totalDiscounts: Money.zero(),
      totalItems: 0,
      averageTransactionValue: Money.zero(),
    );
  }

  final repository = ref.watch(transactionRepositoryProvider);
  return await repository.getTransactionStats(
    deviceId: deviceConfig.deviceId,
    date: deviceConfig.currentShopOpenDate,
  );
});

/// Unsynced transactions count
final unsyncedTransactionsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final deviceConfig = await ref.watch(deviceConfigProvider.future);
  if (deviceConfig == null) return 0;

  final repository = ref.watch(transactionRepositoryProvider);
  final unsynced = await repository.getUnsyncedTransactions(
    deviceConfig.deviceId,
  );

  return unsynced.length;
});

/// Best selling items (last 7 days)
final bestSellingItemsProvider =
    FutureProvider.autoDispose<List<ItemSalesStats>>((ref) async {
  final deviceConfig = await ref.watch(deviceConfigProvider.future);
  if (deviceConfig == null) return [];

  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 7));

  final startDate = sevenDaysAgo.toIso8601String().substring(0, 10);
  final endDate = now.toIso8601String().substring(0, 10);

  final repository = ref.watch(transactionRepositoryProvider);
  return await repository.getBestSellingItems(
    shopId: deviceConfig.shopId,
    startDate: startDate,
    endDate: endDate,
    limit: 10,
  );
});

/// Transactions by date range
final transactionsByDateRangeProvider = FutureProvider.family<
    List<Transaction>,
    DateRangeParams>((ref, params) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return await repository.getTransactionsByDateRange(
    shopId: params.shopId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

// ==================== PARAMETER CLASSES ====================

class DateRangeParams {
  final String shopId;
  final String startDate;
  final String endDate;

  DateRangeParams({
    required this.shopId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRangeParams &&
          runtimeType == other.runtimeType &&
          shopId == other.shopId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      shopId.hashCode ^ startDate.hashCode ^ endDate.hashCode;
} */