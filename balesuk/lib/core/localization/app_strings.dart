/// Centralized localization strings for Balesuk POS
/// Default language: Amharic (አማርኛ)
/// Extensible to other Ethiopian languages
class AppStrings {
  // Private constructor to prevent instantiation
  AppStrings._();

  // Current language (default: Amharic)
  static AppLanguage _currentLanguage = AppLanguage.amharic;

  // Get current language
  static AppLanguage get currentLanguage => _currentLanguage;

  // Set language
  static void setLanguage(AppLanguage language) {
    _currentLanguage = language;
  }

  // ==================== GENERAL ====================
  
  static String get appName => _translate(
    am: 'ባለሱቅ',
    en: 'Balesuk',
  );

  static String get ok => _translate(am: 'እሺ', en: 'OK');
  static String get cancel => _translate(am: 'ይቅር', en: 'Cancel');
  static String get save => _translate(am: 'አስቀምጥ', en: 'Save');
  static String get delete => _translate(am: 'ሰርዝ', en: 'Delete');
  static String get edit => _translate(am: 'አስተካክል', en: 'Edit');
  static String get add => _translate(am: 'አክል', en: 'Add');
  static String get search => _translate(am: 'ፈልግ', en: 'Search');
  static String get close => _translate(am: 'ዝጋ', en: 'Close');
  static String get open => _translate(am: 'ክፈት', en: 'Open');
  static String get yes => _translate(am: 'አዎ', en: 'Yes');
  static String get no => _translate(am: 'አይ', en: 'No');
  static String get back => _translate(am: 'ተመለስ', en: 'Back');
  static String get next => _translate(am: 'ቀጣይ', en: 'Next');
  static String get done => _translate(am: 'ጨርሰዋል', en: 'Done');
  static String get loading => _translate(am: 'በመጫን ላይ...', en: 'Loading...');
  static String get retry => _translate(am: 'እንደገና ሞክር', en: 'Retry');

  // ==================== SUCCESS MESSAGES ====================
  
  static String get successGeneric => _translate(
    am: 'በተሳካ ሁኔታ ተጠናቅቋል',
    en: 'Operation completed successfully',
  );

  static String get itemSavedSuccess => _translate(
    am: 'እቃው በተሳካ ሁኔታ ተቀምጧል',
    en: 'Item saved successfully',
  );

  static String get familySavedSuccess => _translate(
    am: 'ቤተሰብ በተሳካ ሁኔታ ተቀምጧል',
    en: 'Family saved successfully',
  );

  static String get transactionSavedSuccess => _translate(
    am: 'ሽያጭ በተሳካ ሁኔታ ተቀምጧል',
    en: 'Transaction saved successfully',
  );

  static String get shopOpenedSuccess => _translate(
    am: 'ሱቅ በተሳካ ሁኔታ ተከፈተ',
    en: 'Shop opened successfully',
  );

  static String get shopClosedSuccess => _translate(
    am: 'ሱቅ በተሳካ ሁኔታ ተዘግቷል',
    en: 'Shop closed successfully',
  );

  static String get syncCompletedSuccess => _translate(
    am: 'ማመሳሰል በተሳካ ሁኔታ ተጠናቅቋል',
    en: 'Sync completed successfully',
  );

  static String get setupCompletedSuccess => _translate(
    am: 'ማዋቀር በተሳካ ሁኔታ ተጠናቅቋል',
    en: 'Setup completed successfully',
  );

  // ==================== ERROR MESSAGES ====================
  
  static String get errorGeneric => _translate(
    am: 'ስህተት ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።',
    en: 'An error occurred. Please try again.',
  );

  static String get errorInvalidInput => _translate(
    am: 'ልክ ያልሆነ ግቤት። እባክዎ ያረጋግጡ።',
    en: 'Invalid input. Please check.',
  );

  static String get errorRequiredField => _translate(
    am: 'ይህ ሜዳ ያስፈልጋል',
    en: 'This field is required',
  );

  static String get errorItemNotFound => _translate(
    am: 'እቃው አልተገኘም',
    en: 'Item not found',
  );

  static String get errorInsufficientStock => _translate(
    am: 'በቂ ዕቃ የለም',
    en: 'Insufficient stock',
  );

  static String get errorShopClosed => _translate(
    am: 'ሱቅ ተዘግቷል። እባክዎ በመጀመሪያ ሱቁን ይክፈቱ።',
    en: 'Shop is closed. Please open the shop first.',
  );

  static String get errorSyncFailed => _translate(
    am: 'ማመሳሰል አልተሳካም። እባክዎ እንደገና ይሞክሩ।',
    en: 'Sync failed. Please try again.',
  );

  static String get errorNetworkConnection => _translate(
    am: 'የኔትወርክ ግንኙነት ችግር',
    en: 'Network connection error',
  );

  static String get errorDeviceNotFound => _translate(
    am: 'መሣሪያ አልተገኘም',
    en: 'Device not found',
  );

  static String get errorPriceMismatch => _translate(
    am: 'የዋጋ ልዩነት ተገኝቷል',
    en: 'Price mismatch detected',
  );

  static String get errorUnknownItem => _translate(
    am: 'ያልታወቀ እቃ ተገኝቷል',
    en: 'Unknown item detected',
  );

  static String errorInvalidItemId(String itemId) => _translate(
    am: 'ልክ ያልሆነ የእቃ መለያ: $itemId',
    en: 'Invalid item ID: $itemId',
  );

  static String errorSyncFailedUnknownItem(String itemId, String transactionId) => _translate(
    am: 'ማመሳሰል አልተሳካም: ያልታወቀ እቃ $itemId በግብይት $transactionId ውስጥ',
    en: 'Sync failed: Unknown item $itemId in transaction $transactionId',
  );

  // ==================== MODE SELECTION ====================
  
  static String get selectDeviceMode => _translate(
    am: 'የመሣሪያ ሁነታ ይምረጡ',
    en: 'Select Device Mode',
  );

  static String get modeSelectionDescription => _translate(
    am: 'ይህንን መሳሪያ እንዴት መጠቀም እንደሚፈልጉ ይምረጡ። ይህ ቅንብር በኋላ መቀየር አይችሉም።',
    en: 'Choose how you want to use this device. This setting cannot be changed later.',
  );

  static String get adminMode => _translate(am: 'አስተዳዳሪ', en: 'Admin Mode');
  static String get userMode => _translate(am: 'ተጠቃሚ', en: 'User Mode');

  static String get adminModeDescription => _translate(
    am: 'ሙሉ መዳረሻ ወደ ዕቃ ዝርዝር፣ ሽያጭ እና ማመሳሰል አስተዳደር',
    en: 'Full access to inventory, sales, and sync management',
  );

  static String get userModeDescription => _translate(
    am: 'ሽያጭ መመዝገብ እና መረጃ ከአስተዳዳሪ መሳሪያ ማመሳሰል',
    en: 'Record sales and sync data with admin device',
  );

  // ==================== SHOP ====================
  
  static String get shop => _translate(am: 'ሱቅ', en: 'Shop');
  static String get shopStatus => _translate(am: 'የሱቅ ሁኔታ', en: 'Shop Status');
  static String get shopOpen => _translate(am: 'ሱቅ ክፍት', en: 'Shop Open');
  static String get shopClosed => _translate(am: 'ሱቅ ተዘግቷል', en: 'Shop Closed');
  static String get openShop => _translate(am: 'ሱቅ ክፈት', en: 'Open Shop');
  static String get closeShop => _translate(am: 'ሱቅ ዝጋ', en: 'Close Shop');
  static String get shopName => _translate(am: 'የሱቅ ስም', en: 'Shop Name');
  static String get shopId => _translate(am: 'የሱቅ መለያ', en: 'Shop ID');

  static String get confirmCloseShop => _translate(
    am: 'ሱቁን መዝጋት እርግጠኛ ነዎት?',
    en: 'Are you sure you want to close the shop?',
  );

  // ==================== INVENTORY ====================
  
  static String get inventory => _translate(am: 'ዕቃ ዝርዝር', en: 'Inventory');
  static String get inventoryManagement => _translate(
    am: 'የዕቃ ዝርዝር አስተዳደር',
    en: 'Inventory Management',
  );

  static String get totalFamilies => _translate(am: 'ጠቅላላ ቤተሰቦች', en: 'Total Families');
  static String get totalItems => _translate(am: 'ጠቅላላ እቃዎች', en: 'Total Items');
  static String get totalValue => _translate(am: 'ጠቅላላ ዋጋ', en: 'Total Value');
  static String get lowStock => _translate(am: 'ዝቅተኛ አቅርቦት', en: 'Low Stock');

  static String get family => _translate(am: 'ቤተሰብ', en: 'Family');
  static String get addFamily => _translate(am: 'ቤተሰብ አክል', en: 'Add Family');
  static String get createFamily => _translate(am: 'ቤተሰብ ፍጠር', en: 'Create Family');
  static String get familyName => _translate(am: 'የቤተሰብ ስም', en: 'Family Name');
  static String get familyDescription => _translate(
    am: 'የቤተሰብ መግለጫ',
    en: 'Family Description',
  );

  static String get item => _translate(am: 'እቃ', en: 'Item');
  static String get addItem => _translate(am: 'እቃ አክል', en: 'Add Item');
  static String get createItem => _translate(am: 'እቃ ፍጠር', en: 'Create Item');
  static String get bulkCreateItems => _translate(
    am: 'በብዛት እቃዎች ፍጠር',
    en: 'Bulk Create Items',
  );
  static String get itemName => _translate(am: 'የእቃ ስም', en: 'Item Name');
  static String get itemId => _translate(am: 'የእቃ መለያ', en: 'Item ID');
  static String get price => _translate(am: 'ዋጋ', en: 'Price');
  static String get quantity => _translate(am: 'ብዛት', en: 'Quantity');
  static String get minQuantity => _translate(am: 'ዝቅተኛ ብዛት', en: 'Min Quantity');

  static String get searchFamiliesOrItems => _translate(
    am: 'ቤተሰቦችን ወይም እቃዎችን ፈልግ...',
    en: 'Search families or items...',
  );

  // ==================== SALES ====================
  
  static String get newSale => _translate(am: 'አዲስ ሽያጭ', en: 'New Sale');
  static String get sales => _translate(am: 'ሽያጮች', en: 'Sales');
  static String get transaction => _translate(am: 'ግብይት', en: 'Transaction');
  static String get transactions => _translate(am: 'ግብይቶች', en: 'Transactions');
  static String get transactionId => _translate(am: 'የግብይት መለያ', en: 'Transaction ID');
  static String get todayTransactions => _translate(
    am: 'የዛሬ ግብይቶች',
    en: "Today's Transactions",
  );
  static String get todaySales => _translate(am: 'የዛሬ ሽያጮች', en: "Today's Sales");
  
  static String get total => _translate(am: 'ጠቅላላ', en: 'Total');
  static String get subtotal => _translate(am: 'የበኩል ድምር', en: 'Subtotal');
  static String get unitPrice => _translate(am: 'የአንድ ዋጋ', en: 'Unit Price');
  static String get lineTotal => _translate(am: 'የመስመር ድምር', en: 'Line Total');

  static String get completed => _translate(am: 'ተጠናቅቋል', en: 'Completed');
  static String get dube => _translate(am: 'ዱቤ', en: 'DUBE');
  static String get debt => _translate(am: 'ዕዳ', en: 'Debt');
  static String get credit => _translate(am: 'ብድር', en: 'Credit');

  static String get customerName => _translate(am: 'የደንበኛ ስም', en: 'Customer Name');
  static String get customerPhone => _translate(am: 'የደንበኛ ስልክ', en: 'Customer Phone');

  static String get enterItemId => _translate(
    am: 'የእቃ መለያ አስገባ',
    en: 'Enter Item ID',
  );
  static String get scanItemId => _translate(
    am: 'የእቃ መለያ ስካን',
    en: 'Scan Item ID',
  );

  static String get confirmDeleteTransaction => _translate(
    am: 'ይህን ግብይት መሰረዝ እርግጠኛ ነዎት?',
    en: 'Are you sure you want to delete this transaction?',
  );

  // ==================== SYNC ====================
  
  static String get sync => _translate(am: 'ማመሳሰል', en: 'Sync');
  static String get syncData => _translate(am: 'መረጃ አመሳስል', en: 'Sync Data');
  static String get syncHistory => _translate(am: 'የማመሳሰል ታሪክ', en: 'Sync History');
  static String get receiveFromDevices => _translate(
    am: 'ከመሳሪያዎች ተቀበል',
    en: 'Receive from Devices',
  );
  static String get sendToAdmin => _translate(
    am: 'ወደ አስተዳዳሪ ላክ',
    en: 'Send to Admin',
  );
  static String get lastSync => _translate(am: 'የመጨረሻ ማመሳሰል', en: 'Last Sync');
  static String get syncNow => _translate(am: 'አሁን አመሳስል', en: 'Sync Now');
  static String get selectDevice => _translate(am: 'መሳሪያ ምረጥ', en: 'Select Device');
  static String get scanningDevices => _translate(
    am: 'መሳሪያዎችን በመፈለግ ላይ...',
    en: 'Scanning for devices...',
  );
  static String get connectingToDevice => _translate(
    am: 'ወደ መሳሪያ በመገናኘት ላይ...',
    en: 'Connecting to device...',
  );
  static String get syncInProgress => _translate(
    am: 'ማመሳሰል በሂደት ላይ...',
    en: 'Sync in progress...',
  );

  static String syncCompletedTransactions(int count) => _translate(
    am: '$count ግብይቶች በተሳካ ሁኔታ ተመሳስለዋል',
    en: '$count transactions synced successfully',
  );

  // ==================== SETUP ====================
  
  static String get setup => _translate(am: 'ማዋቀር', en: 'Setup');
  static String get adminSetup => _translate(am: 'የአስተዳዳሪ ማዋቀር', en: 'Admin Setup');
  static String get userSetup => _translate(am: 'የተጠቃሚ ማዋቀር', en: 'User Setup');
  static String get deviceId => _translate(am: 'የመሳሪያ መለያ', en: 'Device ID');
  static String get enterDeviceId => _translate(
    am: 'የመሳሪያ መለያ አስገባ',
    en: 'Enter Device ID',
  );
  static String get enterShopId => _translate(
    am: 'የሱቅ መለያ አስገባ',
    en: 'Enter Shop ID',
  );
  static String get configureItemId => _translate(
    am: 'የእቃ መለያ አወቃቀር',
    en: 'Configure Item ID',
  );
  static String get familyDigits => _translate(
    am: 'የቤተሰብ አሃዞች',
    en: 'Family Digits',
  );
  static String get itemDigits => _translate(
    am: 'የእቃ አሃዞች',
    en: 'Item Digits',
  );

  // ==================== ATTRIBUTES ====================
  
  static String get attributes => _translate(am: 'ባህሪያት', en: 'Attributes');
  static String get addAttribute => _translate(am: 'ባህሪ አክል', en: 'Add Attribute');
  static String get attributeName => _translate(am: 'የባህሪ ስም', en: 'Attribute Name');
  static String get attributeType => _translate(am: 'የባህሪ አይነት', en: 'Attribute Type');
  static String get required => _translate(am: 'ያስፈልጋል', en: 'Required');
  static String get optional => _translate(am: 'አማራጭ', en: 'Optional');

  // ==================== VALIDATION MESSAGES ====================
  
  static String fieldRequired(String fieldName) => _translate(
    am: '$fieldName ያስፈልጋል',
    en: '$fieldName is required',
  );

  static String fieldMustBe(String fieldName, String condition) => _translate(
    am: '$fieldName $condition መሆን አለበት',
    en: '$fieldName must be $condition',
  );

  static String mustBeGreaterThan(String fieldName, double value) => _translate(
    am: '$fieldName ከ ${value.toStringAsFixed(0)} በላይ መሆን አለበት',
    en: '$fieldName must be greater than ${value.toStringAsFixed(0)}',
  );

  // ==================== DATE/TIME ====================
  
  static String get today => _translate(am: 'ዛሬ', en: 'Today');
  static String get yesterday => _translate(am: 'ትናንት', en: 'Yesterday');
  static String get date => _translate(am: 'ቀን', en: 'Date');
  static String get time => _translate(am: 'ሰዓት', en: 'Time');

  // Additional localization strings to add to app_strings.dart
// Add these to the AppStrings class in lib/core/localization/app_strings.dart

  // Transaction
  static String get completeTransaction => _translate(
    am: 'ግብይቱን አጠናቅቅ',
    en: 'Complete Transaction',
  );
  
  static String get items => _translate(am: 'እቃዎች', en: 'Items');
  
  // General actions
  static String get remove => _translate(am: 'አስወግድ', en: 'Remove');
  static String get confirm => _translate(am: 'አረጋግጥ', en: 'Confirm');
  
  
  static String get transactionCompleted => _translate(
    am: 'ግብይቱ በተሳካ ሁኔታ ተጠናቀቀ',
    en: 'Transaction completed successfully',
  );



  // ==================== PRIVATE HELPER ====================
  
  static String _translate({
    required String am,
    required String en,
    String? ti,
    String? or,
  }) {
    switch (_currentLanguage) {
      case AppLanguage.amharic:
        return am;
      case AppLanguage.english:
        return en;
      case AppLanguage.tigrinya:
        return ti ?? am; // Fallback to Amharic if Tigrinya not provided
      case AppLanguage.oromo:
        return or ?? am; // Fallback to Amharic if Oromo not provided
    }
  }

  // Add these localization strings to lib/core/localization/app_strings.dart

// ==================== SETUP & MODE SELECTION ====================




static String get completeSetup => _translate(
  am: 'ማዋቀሩን አጠናቅቅ',
  en: 'Complete Setup',
);


  
}

// ==================== LANGUAGE ENUM ====================

enum AppLanguage {
  amharic,   // አማርኛ
  english,   // English
  tigrinya,  // ትግርኛ (future)
  oromo,     // ኦሮሚኛ (future)
}

extension AppLanguageExtension on AppLanguage {
  String get displayName {
    switch (this) {
      case AppLanguage.amharic:
        return 'አማርኛ';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.tigrinya:
        return 'ትግርኛ';
      case AppLanguage.oromo:
        return 'ኦሮሚኛ';
    }
  }

  String get code {
    switch (this) {
      case AppLanguage.amharic:
        return 'am';
      case AppLanguage.english:
        return 'en';
      case AppLanguage.tigrinya:
        return 'ti';
      case AppLanguage.oromo:
        return 'or';
    }
  }
}