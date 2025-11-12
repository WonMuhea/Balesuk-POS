import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/money.dart';
import '../../core/utils/result.dart';
import '../../core/helpers/id_generator.dart';
import '../../core/providers/providers.dart';
import '../database/isar_service.dart';
import '../models/isar_models.dart';

// ==================== DTOs ====================

class CreateTransactionDto {
  final String deviceId;
  final String shopId;
  final String shopOpenDate;
  final int transactionNumber;
  final List<TransactionLineDto> lines;
  final String? customerName;
  final String? customerPhone;

  CreateTransactionDto({
    required this.deviceId,
    required this.shopId,
    required this.shopOpenDate,
    required this.transactionNumber,
    required this.lines,
    this.customerName,
    this.customerPhone,
  });

  Result<void> validate() {
    if (deviceId.trim().isEmpty) {
      return Error(ValidationFailure('Device ID is required'));
    }

    if (shopId.trim().isEmpty) {
      return Error(ValidationFailure('Shop ID is required'));
    }

    if (lines.isEmpty) {
      return Error(ValidationFailure('Transaction must have at least one line'));
    }

    if (transactionNumber < 1) {
      return Error(ValidationFailure('Transaction number must be at least 1'));
    }

    // Validate each line
    for (final line in lines) {
      final lineValidation = line.validate();
      if (lineValidation.isError) {
        return Error(lineValidation.failureOrNull!);
      }
    }

    return const Success(null);
  }

  Money get totalAmount {
    return lines.fold(
      Money.zero,
      (sum, line) => sum + line.lineTotal,
    );
  }
}

class TransactionLineDto {
  final String itemId;
  final String itemName;
  final int quantity;
  final Money unitPrice;

  TransactionLineDto({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
  });

  Money get lineTotal => unitPrice * quantity;

  Result<void> validate() {
    if (itemId.trim().isEmpty) {
      return Error(ValidationFailure('Item ID is required'));
    }

    if (itemName.trim().isEmpty) {
      return Error(ValidationFailure('Item name is required'));
    }

    if (quantity < 1) {
      return Error(ValidationFailure('Quantity must be at least 1'));
    }

    if (unitPrice.amount <= 0) {
      return Error(ValidationFailure('Unit price must be greater than zero'));
    }

    return const Success(null);
  }
}

// ==================== TRANSACTION REPOSITORY ====================

class TransactionRepository with LoggerMixin {
  final IsarService _isarService;

  TransactionRepository(this._isarService);

  // ==================== TRANSACTION OPERATIONS ====================

  /// Get transaction by ID
  Future<Result<Transaction>> getTransactionById(String transactionId) async {
    try {
      logInfo('Fetching transaction: $transactionId');
      final transaction = await _isarService.getTransaction(transactionId);
      
      if (transaction == null) {
        return Error(NotFoundFailure('Transaction not found: $transactionId'));
      }
      
      logSuccess('Transaction fetched: $transactionId');
      return Success(transaction);
    } catch (e, stack) {
      logError('Failed to fetch transaction', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load transaction',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Get transactions for today
  Future<Result<List<Transaction>>> getTodayTransactions({
    required String deviceId,
    required String date,
  }) async {
    try {
      logInfo('Fetching today\'s transactions: $date');
      final transactions = await _isarService.getTodayTransactions(deviceId, date);
      logSuccess('Fetched ${transactions.length} transactions');
      return Success(transactions);
    } catch (e, stack) {
      logError('Failed to fetch today\'s transactions', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load transactions',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Get transactions by date range
  Future<Result<List<Transaction>>> getTransactionsByDateRange({
    required String shopId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      logInfo('Fetching transactions from ${startDate.toIso8601String().substring(0, 10)} to ${endDate.toIso8601String().substring(0, 10)}');
      
      final transactions = await _isarService.getTransactionsByDateRange(
        shopId: shopId,
        startDate: startDate.toIso8601String().substring(0, 10),
        endDate: endDate.toIso8601String().substring(0, 10),
      );
      
      logSuccess('Fetched ${transactions.length} transactions');
      return Success(transactions);
    } catch (e, stack) {
      logError('Failed to fetch transactions by date range', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load transactions',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Get transaction lines
  Future<Result<List<TransactionLine>>> getTransactionLines(String transactionId) async {
    try {
      logInfo('Fetching transaction lines: $transactionId');
      final lines = await _isarService.getTransactionLines(transactionId);
      logSuccess('Fetched ${lines.length} lines');
      return Success(lines);
    } catch (e, stack) {
      logError('Failed to fetch transaction lines', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load transaction lines',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Create a new transaction
  Future<Result<Transaction>> createTransaction(CreateTransactionDto dto) async {
    try {
      // Validate
      final validation = dto.validate();
      if (validation.isError) {
        return Error(validation.failureOrNull!);
      }

      logInfo('Creating transaction #${dto.transactionNumber}');

      // Generate transaction ID
      final transactionId = IdGenerator.generateTransactionId(
        deviceId: dto.deviceId,
        date: dto.shopOpenDate,
        trxCounter: dto.transactionNumber,
      );

      // Check for duplicate transaction ID
      final existing = await _isarService.getTransaction(transactionId);
      if (existing != null) {
        return Error(DuplicateFailure('Transaction $transactionId already exists'));
      }

      // Verify items exist and have sufficient stock
      for (final lineDto in dto.lines) {
        final item = await _isarService.getItemById(lineDto.itemId);
        
        if (item == null) {
          return Error(NotFoundFailure('Item not found: ${lineDto.itemId}'));
        }

        if (!item.isActive) {
          return Error(BusinessRuleFailure('Item ${item.name} is not active'));
        }

        if (item.quantity < lineDto.quantity) {
          return Error(BusinessRuleFailure(
            'Insufficient stock for ${item.name}. Available: ${item.quantity}, Required: ${lineDto.quantity}',
          ));
        }
      }

      // Create transaction
      final transaction = Transaction.create(
        transactionId: transactionId,
        deviceId: dto.deviceId,
        shopId: dto.shopId,
        shopOpenDate: dto.shopOpenDate,
        totalAmountValue: dto.totalAmount,
        customerName: dto.customerName,
        customerPhone: dto.customerPhone,
        status: TransactionStatus.COMPLETED,
        isSynced: false,
        createdAt: DateTime.now(),
      );

      await _isarService.saveTransaction(transaction);

      // Create transaction lines and update inventory
      int lineNumber = 1;
      for (final lineDto in dto.lines) {
        final line = TransactionLine.create(
          transactionId: transactionId,
          lineNumber: lineNumber,
          itemId: lineDto.itemId,
          itemName: lineDto.itemName,
          quantity: lineDto.quantity,
          unitPriceValue: lineDto.unitPrice,
          lineTotalValue: lineDto.lineTotal,
          createdAt: DateTime.now(),
        );

        await _isarService.saveTransactionLine(line);

        // Update item quantity
        final item = await _isarService.getItemById(lineDto.itemId);
        if (item != null) {
          item.quantity -= lineDto.quantity;
          item.updatedAt = DateTime.now();
          await _isarService.saveItem(item);
        }

        lineNumber++;
      }

      logSuccess('Transaction created: $transactionId (${dto.totalAmount.format()})');
      AppLogger.business(
        'Transaction completed',
        details: 'ID: $transactionId, Amount: ${dto.totalAmount.format()}, Items: ${dto.lines.length}',
      );

      return Success(transaction);
    } catch (e, stack) {
      logError('Failed to create transaction', error: e, stackTrace: stack);
      AppLogger.error('Failed to create transaction', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to create transaction',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Cancel a transaction
  Future<Result<Transaction>> cancelTransaction(String transactionId) async {
    try {
      logInfo('Cancelling transaction: $transactionId');

      // Get transaction
      final transactionResult = await getTransactionById(transactionId);
      if (transactionResult.isError) {
        return Error(transactionResult.failureOrNull!);
      }

      final transaction = transactionResult.dataOrNull!;

      // Check if already cancelled
      if (transaction.status == TransactionStatus.CANCELLED) {
        return const Error(BusinessRuleFailure('Transaction is already cancelled'));
      }

      // Check if synced
      if (transaction.isSynced) {
        return const Error(BusinessRuleFailure('Cannot cancel synced transaction'));
      }

      // Get transaction lines
      final linesResult = await getTransactionLines(transactionId);
      if (linesResult.isError) {
        return Error(linesResult.failureOrNull!);
      }

      final lines = linesResult.dataOrNull!;

      // Restore inventory quantities
      for (final line in lines) {
        final item = await _isarService.getItemById(line.itemId);
        if (item != null) {
          item.quantity += line.quantity;
          item.updatedAt = DateTime.now();
          await _isarService.saveItem(item);
        }
      }

      // Update transaction status
      transaction.status = TransactionStatus.CANCELLED;
      await _isarService.saveTransaction(transaction);

      logSuccess('Transaction cancelled: $transactionId');
      AppLogger.business('Transaction cancelled', details: 'ID: $transactionId');

      return Success(transaction);
    } catch (e, stack) {
      logError('Failed to cancel transaction', error: e, stackTrace: stack);
      AppLogger.error('Failed to cancel transaction', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to cancel transaction',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Mark transaction as synced
  Future<Result<Transaction>> markAsSynced(String transactionId) async {
    try {
      logInfo('Marking transaction as synced: $transactionId');

      final transactionResult = await getTransactionById(transactionId);
      if (transactionResult.isError) {
        return Error(transactionResult.failureOrNull!);
      }

      final transaction = transactionResult.dataOrNull!;

      if (transaction.isSynced) {
        return Success(transaction); // Already synced
      }

      transaction.isSynced = true;
      transaction.syncedAt = DateTime.now();
      await _isarService.saveTransaction(transaction);

      logSuccess('Transaction marked as synced: $transactionId');
      return Success(transaction);
    } catch (e, stack) {
      logError('Failed to mark transaction as synced', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to update transaction sync status',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  // ==================== STATISTICS ====================

  /// Get transaction statistics for a date
  Future<Result<Map<String, dynamic>>> getTransactionStats({
    required String deviceId,
    required String date,
  }) async {
    try {
      final transactionsResult = await getTodayTransactions(
        deviceId: deviceId,
        date: date,
      );

      if (transactionsResult.isError) {
        return Error(transactionsResult.failureOrNull!);
      }

      final transactions = transactionsResult.dataOrNull!;
      final completed = transactions.where(
        (t) => t.status == TransactionStatus.COMPLETED,
      ).toList();

      final totalAmount = completed.fold(
        Money.zero,
        (sum, t) => sum + t.totalAsMoney,
      );

      final stats = {
        'totalTransactions': transactions.length,
        'completedTransactions': completed.length,
        'cancelledTransactions': transactions.where(
          (t) => t.status == TransactionStatus.CANCELLED,
        ).length,
        'totalAmount': totalAmount.amount,
        'averageAmount': completed.isEmpty 
            ? 0.0 
            : totalAmount.amount / completed.length,
        'syncedTransactions': completed.where((t) => t.isSynced).length,
        'unsyncedTransactions': completed.where((t) => !t.isSynced).length,
      };

      return Success(stats);
    } catch (e, stack) {
      logError('Failed to get transaction stats', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to calculate statistics',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }

  /// Get unsynced transactions
  Future<Result<List<Transaction>>> getUnsyncedTransactions(String shopId) async {
    try {
      logInfo('Fetching unsynced transactions');
      final transactions = await _isarService.getUnsyncedTransactions(shopId);
      logSuccess('Found ${transactions.length} unsynced transactions');
      return Success(transactions);
    } catch (e, stack) {
      logError('Failed to fetch unsynced transactions', error: e, stackTrace: stack);
      return Error(DatabaseFailure(
        'Failed to load unsynced transactions',
        exception: e as Exception?,
        stackTrace: stack,
      ));
    }
  }
}

// ==================== REPOSITORY PROVIDER ====================

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return TransactionRepository(isarService);
});