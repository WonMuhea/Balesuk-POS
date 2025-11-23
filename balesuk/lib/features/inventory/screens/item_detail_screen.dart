
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../providers/transaction_provider.dart';
// ===================================================================
// 4. ITEM DETAIL SCREEN
// lib/features/inventory/screens/item_detail_screen.dart
// ===================================================================

class ItemDetailScreen extends ConsumerWidget {
  final int itemCode;

  const ItemDetailScreen({super.key, required this.itemCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemDetailProvider(itemCode));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Edit item
            },
          ),
        ],
      ),
      body: itemAsync.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Item not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            if (item.isActive)
                              const Chip(
                                label: Text('Active'),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white),
                              )
                            else
                              const Chip(
                                label: Text('Inactive'),
                                backgroundColor: Colors.grey,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Item Code: ${item.itemId}', style: Theme.of(context).textTheme.bodyLarge),
                        Text('Family: ${item.familyId}', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Price & Stock
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: AppColors.primary.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.attach_money, color: AppColors.primary, size: 32),
                              const SizedBox(height: 8),
                              Text('Price', style: Theme.of(context).textTheme.bodySmall),
                              Text(
                                item.priceAsMoney.format(),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: (item.isLowStock ? AppColors.warning : AppColors.success).withAlpha((255*0.1).round()),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2, color: item.isLowStock ? AppColors.warning : AppColors.success, size: 32),
                              const SizedBox(height: 8),
                              Text('Stock', style: Theme.of(context).textTheme.bodySmall),
                              Text(
                                '${item.quantity}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: item.isLowStock ? AppColors.warning : AppColors.success,
                                    ),
                              ),
                              if (item.isLowStock)
                                Text('Low Stock!', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Details
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Details', style: Theme.of(context).textTheme.titleMedium),
                        const Divider(),
                        _DetailRow('Minimum Stock', '${item.minQuantity}'),
                        _DetailRow('Created', _formatDate(item.createdAt)),
                        _DetailRow('Last Updated', _formatDate(item.updatedAt)),
                        if (item.lastSoldAt != null) _DetailRow('Last Sold', _formatDate(item.lastSoldAt!)),
                        _DetailRow('Inventory Value', item.inventoryValue.format()),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Adjust stock
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Adjust Stock'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}