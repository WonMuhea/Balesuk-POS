// ----------------- app_string_key.dart -----------------

/// Centralized localization keys for all general text, labels, titles, and prompts.
enum AppStringKey {
  // --- GENERAL ACTIONS/LABELS ---
  appName('appName'),
  ok('ok'),
  cancel('cancel'),
  save('save'),
  delete('delete'),
  edit('edit'),
  add('add'),
  search('search'),
  close('close'),
  open('open'),
  yes('yes'),
  no('no'),
  back('back'),
  next('next'),
  done('done'),
  loading('loading'),
  retry('retry'),
  remove('remove'),
  confirm('confirm'),
  items('items'),

  // --- MODE SELECTION ---
  selectDeviceMode('selectDeviceMode'),
  modeSelectionDescription('modeSelectionDescription'),
  adminMode('adminMode'),
  userMode('userMode'),
  adminModeDescription('adminModeDescription'),
  userModeDescription('userModeDescription'),

  // --- SHOP ---
  shop('shop'),
  shopStatus('shopStatus'),
  shopOpen('shopOpen'),
  shopClosed('shopClosed'),
  openShop('openShop'),
  closeShop('closeShop'),
  shopName('shopName'),
  shopId('shopId'),
  confirmCloseShop('confirmCloseShop'),

  // --- INVENTORY ---
  inventory('inventory'),
  inventoryManagement('inventoryManagement'),
  totalFamilies('totalFamilies'),
  totalItems('totalItems'),
  totalValue('totalValue'),
  lowStock('lowStock'),
  family('family'),
  addFamily('addFamily'),
  createFamily('createFamily'),
  familyName('familyName'),
  familyDescription('familyDescription'),
  item('item'),
  addItem('addItem'),
  createItem('createItem'),
  bulkCreateItems('bulkCreateItems'),
  itemName('itemName'),
  itemId('itemId'),
  price('price'),
  quantity('quantity'),
  minQuantity('minQuantity'),
  searchFamiliesOrItems('searchFamiliesOrItems'),

  // --- SALES ---
  newSale('newSale'),
  sales('sales'),
  transaction('transaction'),
  transactions('transactions'),
  transactionId('transactionId'),
  todayTransactions('todayTransactions'),
  todaySales('todaySales'),
  total('total'),
  subtotal('subtotal'),
  unitPrice('unitPrice'),
  lineTotal('lineTotal'),
  completed('completed'),
  dube('dube'),
  debt('debt'),
  credit('credit'),
  customerName('customerName'),
  customerPhone('customerPhone'),
  enterItemId('enterItemId'),
  scanItemId('scanItemId'),
  confirmDeleteTransaction('confirmDeleteTransaction'),
  completeTransaction('completeTransaction'),

  // --- SYNC ---
  sync('sync'),
  syncData('syncData'),
  syncHistory('syncHistory'),
  receiveFromDevices('receiveFromDevices'),
  sendToAdmin('sendToAdmin'),
  lastSync('lastSync'),
  syncNow('syncNow'),
  selectDevice('selectDevice'),
  scanningDevices('scanningDevices'),
  connectingToDevice('connectingToDevice'),
  syncInProgress('syncInProgress'),
  
  // --- SETUP ---
  setup('setup'),
  adminSetup('adminSetup'),
  userSetup('userSetup'),
  deviceId('deviceId'),
  enterDeviceId('enterDeviceId'),
  enterShopId('enterShopId'),
  configureItemId('configureItemId'),
  familyDigits('familyDigits'),
  itemDigits('itemDigits'),
  completeSetup('completeSetup'),

  // --- ATTRIBUTES ---
  attributes('attributes'),
  addAttribute('addAttribute'),
  attributeName('attributeName'),
  attributeType('attributeType'),
  required('required'),
  optional('optional'),

  // --- DATE/TIME ---
  today('today'),
  yesterday('yesterday'),
  date('date'),
  time('time');

  /// The string key used in the .arb localization files.
  final String key;
  const AppStringKey(this.key);
}