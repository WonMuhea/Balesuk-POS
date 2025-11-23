// lib/core/helpers/id_generator.dart

import 'dart:math';

class IdGenerator {
  // ==================== ITEM CODE GENERATION ====================
  
  /// Generate item code from family code and sequence
  /// Returns INTEGER for fast storage and queries
  /// 
  /// Example: familyCode=1, itemSequence=45, familyDigits=2, itemDigits=4
  /// Result: 10045 (integer)
  static int generateItemCode({
    required int familyCode,
    required int itemSequence,
    required int familyDigits,
    required int itemDigits,
  }) {
    if (familyCode < 0) {
      throw ArgumentError('Family code must be non-negative');
    }
    if (itemSequence < 0) {
      throw ArgumentError('Item sequence must be non-negative');
    }

    // Calculate multiplier for item sequence
    final multiplier = pow(10, itemDigits).toInt();
    
    // Combine: familyCode * 10^itemDigits + itemSequence
    // Example: 1 * 10000 + 45 = 10045
    final itemCode = (familyCode * multiplier) + itemSequence;
    
    // Validate total length
    final totalDigits = familyDigits + itemDigits;
    if (!isValidItemCode(itemCode, totalDigits)) {
      throw Exception(
        'Generated item code $itemCode exceeds maximum for $totalDigits digits'
      );
    }
    
    return itemCode;
  }

  /// Format item code to string with leading zeros
  /// Example: 10045 → "010045" (6 digits)
  static String formatItemCode(
    int itemCode, {
    required int totalDigits,
  }) {
    return itemCode.toString().padLeft(totalDigits, '0');
  }

  /// Parse item code from string
  /// Example: "010045" → 10045
  static int parseItemCode(String itemId) {
    final code = int.tryParse(itemId);
    if (code == null) {
      throw FormatException('Invalid item ID format: $itemId');
    }
    return code;
  }

  /// Extract family code from item code
  /// Example: 10045 with 4 item digits → 1
  static int extractFamilyCode(int itemCode, int itemDigits) {
    final divisor = pow(10, itemDigits).toInt();
    return itemCode ~/ divisor;  // Integer division
  }

  /// Extract item sequence from item code
  /// Example: 10045 with 4 item digits → 45
  static int extractItemSequence(int itemCode, int itemDigits) {
    final divisor = pow(10, itemDigits).toInt();
    return itemCode % divisor;  // Modulo
  }

  /// Validate item code range
  static bool isValidItemCode(int itemCode, int totalDigits) {
    if (itemCode < 0) return false;
    final maxCode = pow(10, totalDigits) - 1;
    return itemCode <= maxCode;
  }

  // ==================== FAMILY CODE GENERATION ====================
  
  /// Generate family code from sequence
  static int generateFamilyCode(int sequence) {
    if (sequence < 0) {
      throw ArgumentError('Family sequence must be non-negative');
    }
    return sequence;
  }

  /// Format family code to string with leading zeros
  /// Example: 1 → "01" (2 digits)
  static String formatFamilyCode(int familyCode, int digits) {
    return familyCode.toString().padLeft(digits, '0');
  }

  /// Parse family code from string
  /// Example: "01" → 1
  static int parseFamilyCode(String familyId) {
    final code = int.tryParse(familyId);
    if (code == null) {
      throw FormatException('Invalid family ID format: $familyId');
    }
    return code;
  }

  /// Validate family code range
  static bool isValidFamilyCode(int familyCode, int digits) {
    if (familyCode < 0) return false;
    final maxCode = pow(10, digits) - 1;
    return familyCode <= maxCode;
  }

  static int parseToItemCode(
        String fullItemId,
        int familyDigits,
    ) {
        // 1. Determine the index where the Item Code begins.
        // This is the length of the padded Family Code.
        final splitIndex = familyDigits; 
        // 3. Extract and parse the Item Code (the remaining segment)
        final itemCodeStr = fullItemId.substring(splitIndex); 
        return int.parse(itemCodeStr);
        
    }

  // ==================== TRANSACTION ID GENERATION ====================
  
  /// Generate transaction ID with device prefix and date
  /// Format: DEVICE-YYYYMMDD-COUNTER
  /// Example: "ADM001-20250115-0024"
  static String generateTransactionId({
    required String deviceId,
    required String date,      // Format: YYYYMMDD or YYYY-MM-DD
    required int trxCounter,
  }) {
    // Clean date format
    final dateCode = date.replaceAll('-', '');
    if (dateCode.length != 8) {
      throw ArgumentError('Date must be in YYYYMMDD format, got: $date');
    }
    
    // Validate date is numeric
    if (int.tryParse(dateCode) == null) {
      throw ArgumentError('Date must be numeric: $dateCode');
    }
    
    // Format counter with leading zeros (4 digits)
    final trxCode = trxCounter.toString().padLeft(4, '0');
    
    return '$deviceId-$dateCode-$trxCode';
  }

  /// Validate transaction ID format
  /// Format: XXX###-YYYYMMDD-####
  static bool validateTransactionId(String transactionId) {
    // Pattern: 3 letters + 3 digits - 8 digits - 4 digits
    final pattern = RegExp(r'^[A-Z]{3}\d{3}-\d{8}-\d{4}$');
    return pattern.hasMatch(transactionId);
  }

  /// Extract date from transaction ID
  /// Example: "ADM001-20250115-0024" → "20250115"
  static String extractDateFromTransactionId(String transactionId) {
    final parts = transactionId.split('-');
    if (parts.length != 3) {
      throw ArgumentError('Invalid transaction ID format: $transactionId');
    }
    return parts[1];
  }

  /// Extract counter from transaction ID
  /// Example: "ADM001-20250115-0024" → 24
  static int extractCounterFromTransactionId(String transactionId) {
    final parts = transactionId.split('-');
    if (parts.length != 3) {
      throw ArgumentError('Invalid transaction ID format: $transactionId');
    }
    return int.parse(parts[2]);
  }

  /// Extract device ID from transaction ID
  /// Example: "ADM001-20250115-0024" → "ADM001"
  static String extractDeviceIdFromTransactionId(String transactionId) {
    final parts = transactionId.split('-');
    if (parts.length != 3) {
      throw ArgumentError('Invalid transaction ID format: $transactionId');
    }
    return parts[0];
  }

  // ==================== SHOP & DEVICE ID GENERATION ====================
  
  /// Generate shop ID with random suffix
  /// Format: SHOP#### (4-digit random number)
  static String generateShopId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final suffix = (timestamp % 10000).toString().padLeft(4, '0');
    return 'SHOP$suffix';
  }

  /// Generate device ID
  /// Admin: ADM001, ADM002, etc.
  /// User: DEV001, DEV002, etc.
  static String generateDeviceId({
    required bool isAdmin,
    required int sequence,
  }) {
    final prefix = isAdmin ? 'ADM' : 'DEV';
    final suffix = sequence.toString().padLeft(3, '0');
    return '$prefix$suffix';
  }

  // ==================== UTILITY METHODS ====================
  
  /// Calculate maximum capacity for given digits
  static int calculateMaxCapacity(int digits) {
    return pow(10, digits).toInt() - 1;
  }

  /// Calculate next capacity tier (expand by 1 digit)
  static int calculateNextCapacity(int currentDigits) {
    return calculateMaxCapacity(currentDigits + 1);
  }

  /// Check if sequence is near capacity (80% full)
  static bool isNearCapacity(int sequence, int digits) {
    final maxCapacity = calculateMaxCapacity(digits);
    final threshold = (maxCapacity * 0.8).toInt();
    return sequence >= threshold;
  }

  /// Get recommended digits for expected item count
  static int recommendItemDigits(int expectedItemCount) {
    if (expectedItemCount <= 99) return 2;
    if (expectedItemCount <= 999) return 3;
    if (expectedItemCount <= 9999) return 4;
    if (expectedItemCount <= 99999) return 5;
    return 6;
  }

  /// Format barcode for printing (with leading zeros)
  /// Example: 10045 → "010045" for 6-digit barcode
  static String formatBarcode(int itemCode, {required int totalDigits}) {
    return formatItemCode(itemCode, totalDigits: totalDigits);
  }

  /// Parse scanned barcode to item code
  /// Example: "010045" → 10045
  static int parseBarcodeToItemCode(String barcode) {
    return parseItemCode(barcode);
  }
}