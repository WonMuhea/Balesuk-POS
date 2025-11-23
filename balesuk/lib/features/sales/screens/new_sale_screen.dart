/* import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/isar_models.dart';
import '../../../data/database/isar_service.dart';

// Cart item model for UI
class CartItem {
  final Item item;
  int quantity;
  
  CartItem({
    required this.item,
    this.quantity = 1,
  });
  
  double get lineTotal => item.price * quantity;
  
  CartItem copyWith({int? quantity}) {
    return CartItem(
      item: item,
      quantity: quantity ?? this.quantity,
    );
  }
}

// Sale state provider
class SaleState {
  final List<CartItem> cartItems;
  final String? customerName;
  final String? customerPhone;
  final bool isProcessing;
  
  SaleState({
    this.cartItems = const [],
    this.customerName,
    this.customerPhone,
    this.isProcessing = false,
  });
  
  double get subtotal => cartItems.fold(
    0.0, 
    (sum, item) => sum + item.lineTotal,
  );
  
  int get totalItems => cartItems.fold(
    0,
    (sum, item) => sum + item.quantity,
  );
  
  SaleState copyWith({
    List<CartItem>? cartItems,
    String? customerName,
    String? customerPhone,
    bool? isProcessing,
  }) {
    return SaleState(
      cartItems: cartItems ?? this.cartItems,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

// Sale notifier
class SaleNotifier extends StateNotifier<SaleState> with LoggerMixin {
  final IsarService isarService;
  
  SaleNotifier(this.isarService) : super(SaleState());
  
  void addItem(Item item, {int quantity = 1}) {
    final existingIndex = state.cartItems.indexWhere(
      (cartItem) => cartItem.item.itemId == item.itemId,
    );
    
    List<CartItem> updatedCart;
    if (existingIndex != -1) {
      // Update quantity of existing item
      updatedCart = [...state.cartItems];
      updatedCart[existingIndex] = updatedCart[existingIndex].copyWith(
        quantity: updatedCart[existingIndex].quantity + quantity,
      );
    } else {
      // Add new item
      updatedCart = [
        ...state.cartItems,
        CartItem(item: item, quantity: quantity),
      ];
    }
    
    state = state.copyWith(cartItems: updatedCart);
  }
  
  void updateQuantity(String itemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(itemId);
      return;
    }
    
    final updatedCart = state.cartItems.map((cartItem) {
      if (cartItem.item.itemId == itemId) {
        return cartItem.copyWith(quantity: newQuantity);
      }
      return cartItem;
    }).toList();
    
    state = state.copyWith(cartItems: updatedCart);
  }
  
  void removeItem(String itemId) {
    final updatedCart = state.cartItems
        .where((cartItem) => cartItem.item.itemId != itemId)
        .toList();
    
    state = state.copyWith(cartItems: updatedCart);
  }
  
  void setCustomerInfo(String? name, String? phone) {
    state = state.copyWith(
      customerName: name,
      customerPhone: phone,
    );
  }
  
  void clearCart() {
    state = SaleState();
  }
  
  Future<String?> completeSale({
    required String shopId,
    required String deviceId,
    required String shopOpenDate,
  }) async {
    if (state.cartItems.isEmpty) {
      return 'Cart is empty';
    }
    
    state = state.copyWith(isProcessing: true);
    
    try {
      // Create transaction
      final transaction = Transaction()
        ..transactionId = 'TRX-${DateTime.now().millisecondsSinceEpoch}'
        ..shopId = shopId
        ..deviceId = deviceId
        ..shopOpenDate = shopOpenDate
        ..totalAmount = state.subtotal
        ..customerName = state.customerName
        ..customerPhone = state.customerPhone
        ..status = TransactionStatus.COMPLETED
        ..createdAt = DateTime.now()
        ..isSynced = false;
      
      // Save transaction and transaction lines
      await isarService.saveTransaction(transaction);
      
      // Create and save transaction lines
      final lines = <TransactionLine>[];
      for (var cartItem in state.cartItems) {
        final line = TransactionLine()
          ..transactionId = transaction.transactionId
          ..itemId = cartItem.item.itemId
          ..quantity = cartItem.quantity
          ..unitPrice = cartItem.item.price
          ..lineTotal = cartItem.lineTotal
          ..createdAt = DateTime.now();
        
        lines.add(line);
        
        // Update item quantity using the IsarService method
        await isarService.updateItemQuantity(
          cartItem.item.itemId, 
          -cartItem.quantity, // Negative delta to reduce quantity
        );
      }
      
      // Save all transaction lines at once
      await isarService.saveMultipleTransactionLines(lines);
      
      logSuccess('Transaction completed: ${transaction.transactionId}');
      AppLogger.transaction(
        'Sale completed',
        details: 'TXN: ${transaction.transactionId}, Total: ${state.subtotal}',
      );
      
      // Clear cart after successful sale
      clearCart();
      
      return null; // Success
    } catch (e, stack) {
      logError('Failed to complete sale', error: e, stackTrace: stack);
      state = state.copyWith(isProcessing: false);
      return e.toString();
    }
  }
}

// Provider
final saleProvider = StateNotifierProvider<SaleNotifier, SaleState>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return SaleNotifier(isarService);
});

class NewSaleScreen extends ConsumerStatefulWidget {
  final bool isAdmin;
  
  const NewSaleScreen({
    super.key,
    this.isAdmin = false,
  });

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> with LoggerMixin {
  final TextEditingController _itemIdController = TextEditingController();
  final FocusNode _itemIdFocus = FocusNode();
  
  @override
  void initState() {
    super.initState();
    // Auto-focus on item ID field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _itemIdFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _itemIdController.dispose();
    _itemIdFocus.dispose();
    super.dispose();
  }

  Future<void> _scanOrEnterItem(String itemId) async {
    if (itemId.trim().isEmpty) return;
    
    try {
      // Search for item using IsarService
      final item = await ref.read(saleProvider.notifier).getItemById(itemId.trim());
      
      if (item == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item not found: $itemId'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      
      // Check stock
      if (item.quantity <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item out of stock: ${item.name}'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }
      
      // Add to cart
      ref.read(saleProvider.notifier).addItem(item);
      
      // Clear input and refocus
      _itemIdController.clear();
      _itemIdFocus.requestFocus();
      
    } catch (e, stack) {
      logError('Error adding item', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _completeSale() async {
    final deviceConfig = ref.read(deviceConfigProvider).value;
    if (deviceConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device not configured'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    final error = await ref.read(saleProvider.notifier).completeSale(
      shopId: deviceConfig.shopId,
      deviceId: deviceConfig.deviceId,
      shopOpenDate: deviceConfig.currentShopOpenDate,
    );
    
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Success
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale completed successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showCustomerInfoDialog() {
    final customerNameController = TextEditingController();
    final customerPhoneController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.customerName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customerNameController,
              decoration: InputDecoration(
                labelText: AppStrings.customerName,
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: customerPhoneController,
              decoration: InputDecoration(
                labelText: AppStrings.customerPhone,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(saleProvider.notifier).setCustomerInfo(
                customerNameController.text.trim().isEmpty 
                    ? null 
                    : customerNameController.text.trim(),
                customerPhoneController.text.trim().isEmpty
                    ? null
                    : customerPhoneController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saleState = ref.watch(saleProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.newSale),
        actions: [
          // Customer info button
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showCustomerInfoDialog,
            tooltip: 'Add customer info',
          ),
          // Clear cart button
          if (saleState.cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text('Are you sure you want to clear all items?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(saleProvider.notifier).clearCart();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        child: Text(AppStrings.confirm),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Clear cart',
            ),
        ],
      ),
      body: Column(
        children: [
          // Item search/scan section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.05).round()),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemIdController,
                    focusNode: _itemIdFocus,
                    decoration: InputDecoration(
                      hintText: AppStrings.enterItemId,
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onSubmitted: _scanOrEnterItem,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _scanOrEnterItem(_itemIdController.text),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(AppStrings.add),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Cart items list
          Expanded(
            child: saleState.cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cart is empty',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.scanItemId,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: saleState.cartItems.length,
                    itemBuilder: (context, index) {
                      final cartItem = saleState.cartItems[index];
                      return _CartItemCard(
                        cartItem: cartItem,
                        onQuantityChanged: (newQty) {
                          ref.read(saleProvider.notifier).updateQuantity(
                            cartItem.item.itemId,
                            newQty,
                          );
                        },
                        onRemove: () {
                          ref.read(saleProvider.notifier).removeItem(
                            cartItem.item.itemId,
                          );
                        },
                      );
                    },
                  ),
          ),
          
          // Bottom summary and checkout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.1).round()),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Customer info display
                  if (saleState.customerName != null || 
                      saleState.customerPhone != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withAlpha((255 * 0.1).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (saleState.customerName != null)
                                  Text(
                                    saleState.customerName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (saleState.customerPhone != null)
                                  Text(
                                    saleState.customerPhone!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${saleState.totalItems} ${AppStrings.items}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.total,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'ብር ${saleState.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Checkout button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saleState.cartItems.isEmpty || 
                              saleState.isProcessing
                          ? null
                          : _completeSale,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppColors.success,
                        disabledBackgroundColor: AppColors.textTertiary,
                      ),
                      child: saleState.isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  AppStrings.completeTransaction,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.cartItem,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${cartItem.item.itemId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'ብር ${cartItem.item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        ' × ${cartItem.quantity}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Quantity controls
            Column(
              children: [
                // Line total
                Text(
                  'ብር ${cartItem.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Quantity controls
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (cartItem.quantity > 1) {
                          onQuantityChanged(cartItem.quantity - 1);
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.error,
                      iconSize: 28,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withAlpha((255*0.1).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${cartItem.quantity}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Check stock availability
                        if (cartItem.quantity < cartItem.item.quantity) {
                          onQuantityChanged(cartItem.quantity + 1);
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.success,
                      iconSize: 28,
                    ),
                  ],
                ),
                
                // Remove button
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete, size: 16),
                  label: Text(AppStrings.remove),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} */