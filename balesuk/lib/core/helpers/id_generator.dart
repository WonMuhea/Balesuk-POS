class IdGenerator {
  /// Generates a 6-digit item ID from family ID and item sequence number
  /// Example: familyId="01", itemSequence=45, familyDigits=2, itemDigits=4 => "010045"
  static String generateItemId({
    required String familyId,
    required int itemSequence,
    required int familyDigits,
    required int itemDigits,
  }) {
    if (familyDigits + itemDigits != 6) {
      throw ArgumentError('Family + item digits must equal 6');
    }

    final familyPart = familyId.padLeft(familyDigits, '0');
    final itemPart = itemSequence.toString().padLeft(itemDigits, '0');
    final itemId = familyPart + itemPart;

    if (itemId.length != 6) {
      throw Exception('Item ID must be exactly 6 digits. Got: $itemId');
    }

    return itemId;
  }

  /// Generates a transaction ID from device ID, date, and sequence number
  /// Example: deviceId="DEV001", date="2023-10-27", sequenceNumber=24 => "DEV001-231027-0024"
  static String generateTransactionId({
    required String deviceId,
    required String date, // Expects "YYYY-MM-DD"
    required int sequenceNumber,
  }) {
    final datePart = date.replaceAll('-', '').substring(2); // YYMMDD
    final sequencePart = sequenceNumber.toString().padLeft(4, '0');
    return '$deviceId-$datePart-$sequencePart';
  }

  /// Generates a shop ID with specified length (6-10 characters)
  /// Format: SHOP + random number
  static String generateShopId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final suffix = (timestamp % 10000).toString().padLeft(4, '0');
    return 'SHOP$suffix';
  }

  /// Generates a device ID
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

  /// Generates family ID based on sequence and digit length
  /// Example: sequence=1, digits=2 => "01"
  static String generateFamilyId({
    required int sequence,
    required int digits,
  }) {
    return sequence.toString().padLeft(digits, '0');
  }

  /// Validates if an item ID is correctly formatted
  static bool validateItemId(String itemId) {
    if (itemId.length != 6) return false;
    return RegExp(r'^\d{6}$').hasMatch(itemId);
  }

  /// Validates if a transaction ID is correctly formatted
  static bool validateTransactionId(String transactionId) {
    return RegExp(r'^[A-Z]{3}\d{3}-\d{4}$').hasMatch(transactionId);
  }

  /// Extracts family ID from item ID
  static String extractFamilyId(String itemId, int familyDigits) {
    if (itemId.length != 6) {
      throw ArgumentError('Item ID must be 6 digits');
    }
    return itemId.substring(0, familyDigits);
  }

  /// Extracts item sequence from item ID
  static int extractItemSequence(String itemId, int familyDigits) {
    if (itemId.length != 6) {
      throw ArgumentError('Item ID must be 6 digits');
    }
    final itemPart = itemId.substring(familyDigits);
    return int.parse(itemPart);
  }
}