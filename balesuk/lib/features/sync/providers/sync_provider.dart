/* // ==================== ADD THESE METHODS TO isar_service.dart ====================

// ==================== FAMILY QUERIES (ADD) ====================

/// Delete a family
Future<void> deleteFamily(String familyId) async {
  final db = await isar;
  await db.writeTxn(() async {
    final family = await db.itemFamilys
        .filter()
        .familyIdEqualTo(familyId)
        .findFirst();
    
    if (family != null) {
      await db.itemFamilys.delete(family.id);
    }
  });
}

/// Get family by ID
Future<ItemFamily?> getFamilyById(String familyId) async {
  final db = await isar;
  return await db.itemFamilys
      .filter()
      .familyIdEqualTo(familyId)
      .findFirst();
}

// ==================== ATTRIBUTE QUERIES (ADD) ====================

/// Get attribute definition by ID
Future<AttributeDefinition?> getAttributeDefinitionById(int id) async {
  final db = await isar;
  return await db.attributeDefinitions.get(id);
}

/// Get all item IDs that use a specific attribute definition
Future<List<String>> getItemsWithAttribute(int attributeDefId) async {
  final db = await isar;
  final attributes = await db.itemAttributes
      .filter()
      .attributeDefinitionIdEqualTo(attributeDefId)
      .findAll();
  
  // Return unique item IDs
  return attributes.map((a) => a.itemId).toSet().toList();
}

/// Delete an attribute definition
Future<void> deleteAttributeDefinition(int attributeId) async {
  final db = await isar;
  await db.writeTxn(() async {
    await db.attributeDefinitions.delete(attributeId);
  });
}

/// Delete an item attribute
Future<void> deleteItemAttribute(int attributeId) async {
  final db = await isar;
  await db.writeTxn(() async {
    await db.itemAttributes.delete(attributeId);
  });
}

// ==================== TRANSACTION QUERIES (ADD) ====================

/// Get transactions by date range
Future<List<Transaction>> getTransactionsByDateRange({
  required String shopId,
  required String startDate,
  required String endDate,
}) async {
  final db = await isar;
  return await db.transactions
      .filter()
      .shopIdEqualTo(shopId)
      .and()
      .shopOpenDateBetween(startDate, endDate)
      .sortByCreatedAtDesc()
      .findAll();
}

/// Get unsynced transactions for a shop
Future<List<Transaction>> getUnsyncedTransactionsByShop(String shopId) async {
  final db = await isar;
  return await db.transactions
      .filter()
      .shopIdEqualTo(shopId)
      .and()
      .isSyncedEqualTo(false)
      .sortByCreatedAtDesc()
      .findAll();
}
 */