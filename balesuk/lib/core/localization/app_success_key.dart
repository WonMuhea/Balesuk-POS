// ----------------- app_success_key.dart -----------------

/// Centralized localization keys for all Success messages.
enum AppSuccessKey {
  successGeneric('successGeneric'),
  itemSavedSuccess('itemSavedSuccess'),
  familySavedSuccess('familySavedSuccess'),
  transactionSavedSuccess('transactionSavedSuccess'),
  transactionCompleted('transactionCompleted'),
  shopOpenedSuccess('shopOpenedSuccess'),
  shopClosedSuccess('shopClosedSuccess'),
  syncCompletedSuccess('syncCompletedSuccess'),
  setupCompletedSuccess('setupCompletedSuccess'),
  familyDeletedSuccess('familyDeletedSuccess'),
  itemDeletedSuccess('itemDeletedSuccess'),
  transactionDeletedSuccess('transactionDeletedSuccess'),
  transactionUpdatedSuccess('transactionUpdatedSuccess'),
  transactionItemAddedSuccess('transactionItemAddedSuccess'),
  transactionItemRemovedSuccess('transactionItemRemovedSuccess'), 
  failyupdatedSuccess('failyupdatedSuccess'),
  itemUpdatedSuccess('itemUpdatedSuccess'),
  typeUpdatedSuccess('typeUpdatedSuccess'),
  // --- PARAMETERIZED SUCCESSES ---
  syncCompletedTransactions('syncCompletedTransactions');


  /// The string key used in the .arb localization files.
  final String key;
  const AppSuccessKey(this.key);
}