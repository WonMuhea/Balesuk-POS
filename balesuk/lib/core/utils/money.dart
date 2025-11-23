import 'package:intl/intl.dart';

/// Money class for handling currency operations with 2 decimal precision
/// All monetary values in the app should use this class
class Money {
  final double _amount;

  // Private constructor to ensure validation
  const Money._(this._amount);

  /// Creates Money from double, automatically rounds to 2 decimals
  factory Money.fromDouble(double amount) {
    return Money._(_roundTo2Decimals(amount));
  }

  /// Creates Money from integer (birr)
  factory Money.fromInt(int amount) {
    return Money._(amount.toDouble());
  }

  /// Zero money value
  factory Money.zero() {
    return const Money._(0.0);
  }

  /// Creates Money from string
  factory Money.parse(String amount) {
    final parsed = double.tryParse(amount);
    if (parsed == null) {
      throw FormatException('Invalid money format: $amount');
    }
    return Money.fromDouble(parsed);
  }


  /// Get the raw amount value
  double get amount => _amount;

  /// Get amount as integer (cents/santim)
  int get cents => (_amount * 100).round();

  /// Check if money is zero
  bool get isZero => _amount == 0.0;

  /// Check if money is positive
  bool get isPositive => _amount > 0.0;

  /// Check if money is negative
  bool get isNegative => _amount < 0.0;

  // ==================== ARITHMETIC OPERATIONS ====================

  /// Add two money values
  Money operator +(Money other) {
    return Money.fromDouble(_amount + other._amount);
  }

  /// Subtract two money values
  Money operator -(Money other) {
    return Money.fromDouble(_amount - other._amount);
  }

  /// Multiply money by a number
  Money operator *(num multiplier) {
    return Money.fromDouble(_amount * multiplier);
  }

  /// Divide money by a number
  Money operator /(num divisor) {
    if (divisor == 0) {
      throw ArgumentError('Cannot divide money by zero');
    }
    return Money.fromDouble(_amount / divisor);
  }

  /// Negate money value
  Money operator -() {
    return Money._(-_amount);
  }

  // ==================== COMPARISON OPERATIONS ====================

  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Money && _amount == other._amount;
  }

  @override
  int get hashCode => _amount.hashCode;

  bool operator <(Money other) => _amount < other._amount;
  bool operator <=(Money other) => _amount <= other._amount;
  bool operator >(Money other) => _amount > other._amount;
  bool operator >=(Money other) => _amount >= other._amount;

  // ==================== UTILITY METHODS ====================

  /// Get absolute value
  Money abs() {
    return Money._(_amount.abs());
  }

  bool equals(Money other) {
    return _amount == other._amount;
  }
  
  bool notEquals(Money other) {
    return _amount != other._amount;
  }
  /// Get minimum of two money values
  Money min(Money other) {
    return _amount < other._amount ? this : other;
  }

  /// Get maximum of two money values
  Money max(Money other) {
    return _amount > other._amount ? this : other;
  }

  /// Round to nearest birr (no santim)
  Money roundToBirr() {
    return Money._(_amount.roundToDouble());
  }

  /// Floor to birr
  Money floorToBirr() {
    return Money._(_amount.floorToDouble());
  }

  /// Ceiling to birr
  Money ceilingToBirr() {
    return Money._(_amount.ceilToDouble());
  }

  /// Calculate percentage
  Money percentage(double percent) {
    return Money.fromDouble(_amount * (percent / 100));
  }

  /// Add percentage
  Money addPercentage(double percent) {
    return this + percentage(percent);
  }

  /// Subtract percentage
  Money subtractPercentage(double percent) {
    return this - percentage(percent);
  }

  // ==================== FORMATTING ====================

  /// Format as currency string with Birr symbol
  /// Example: "ብር 1,234.56"
  String format({bool includeSymbol = true}) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formatted = formatter.format(_amount);
    return includeSymbol ? 'ብር $formatted' : formatted;
  }

  /// Format as currency string with "Br" prefix
  /// Example: "Br 1,234.56"
  String formatWithBr() {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'Br ${formatter.format(_amount)}';
  }

  /// Format without decimals
  /// Example: "ብር 1,235"
  String formatWhole({bool includeSymbol = true}) {
    final formatter = NumberFormat('#,##0', 'en_US');
    final formatted = formatter.format(_amount.round());
    return includeSymbol ? 'ብር $formatted' : formatted;
  }

  /// Format for display in tight spaces
  /// Example: "1.2K", "12.5K", "1.2M"
  String formatCompact() {
    if (_amount >= 1000000) {
      return 'ብር ${(_amount / 1000000).toStringAsFixed(1)}M';
    } else if (_amount >= 1000) {
      return 'ብር ${(_amount / 1000).toStringAsFixed(1)}K';
    } else {
      return format();
    }
  }

  /// Convert to plain string representation
  @override
  String toString() {
    return _amount.toStringAsFixed(2);
  }

  /// Convert to JSON-serializable double
  double toJson() => _amount;

  /// Create from JSON double
  factory Money.fromJson(double amount) => Money.fromDouble(amount);

  // ==================== PRIVATE HELPERS ====================

  static double _roundTo2Decimals(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

// ==================== MONEY COLLECTION EXTENSIONS ====================

extension MoneyListExtension on List<Money> {
  /// Sum all money values in the list
  Money sum() {
    if (isEmpty) return Money.zero();
    return fold(Money.zero(), (sum, money) => sum + money);
  }

  /// Get average of all money values
  Money average() {
    if (isEmpty) return Money.zero();
    return sum() / length;
  }

  /// Get minimum value
  Money minimum() {
    if (isEmpty) return Money.zero();
    return reduce((a, b) => a < b ? a : b);
  }

  /// Get maximum value
  Money maximum() {
    if (isEmpty) return Money.zero();
    return reduce((a, b) => a > b ? a : b);
  }
}

// ==================== CONVENIENCE EXTENSIONS ====================

extension DoubleToMoney on double {
  /// Convert double to Money
  Money get birr => Money.fromDouble(this);
}

extension IntToMoney on int {
  /// Convert int to Money
  Money get birr => Money.fromInt(this);
}

extension StringToMoney on String {
  /// Convert string to Money
  Money get toMoney => Money.parse(this);
}