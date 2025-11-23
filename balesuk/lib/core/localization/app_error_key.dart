// ----------------- app_error_key.dart -----------------

/// Centralized localization keys for all Error messages (Failures).
enum AppErrorKey {
  // --- GENERIC ERRORS ---
  errorGeneric('errorGeneric'),
  errorInvalidInput('errorInvalidInput'),
  errorRequiredField('errorRequiredField'),
  errorInsufficientStock('errorInsufficientStock'),
  errorShopClosed('errorShopClosed'),
  errorSyncFailed('errorSyncFailed'),
  errorNetworkConnection('errorNetworkConnection'),
  errorPriceMismatch('errorPriceMismatch'),
  errorUnknownItem('errorUnknownItem'),
  
  // --- PARAMETERIZED ERRORS ---
  errorInvalidItemId('errorInvalidItemId'),
  errorSyncFailedUnknownItem('errorSyncFailedUnknownItem'),
  fieldRequired('fieldRequired'),
  fieldMustBe('fieldMustBe'),
  mustBeGreaterThan('mustBeGreaterThan'),
  errorDuplicateEntry('error_duplicate_entry'),
  errinvalidInputLength('errinvalidInputLength'),
  familyHasActiveItems('familyHasActiveItems'),
  typeUpdateError('typeUpdateError'),
  emptyUpdateData('emptyUpdateData'),
  typeDeleteError('typeDeleteError'),
  notFoundWithId('notFoundWithId'),
  notFound('notFound'),
  errinvalidInputRange('errinvalidInputRange'),
  quantityExceedsStock('quantityExceedsStock');

  /// The string key used in the .arb localization files.
  final String key;
  const AppErrorKey(this.key);
}