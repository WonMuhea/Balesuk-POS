/* 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../providers/transaction_provider.dart';/*  */
// ===================================================================
// 3. TRANSACTION DETAIL SCREEN  
// lib/features/sales/screens/transaction_detail_screen.dart
// ===================================================================

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionDetailProvider(transactionId));
    final linesAsync = ref.watch(transactionLinesProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share transaction
            },
          ),
        ],
      ),
      body: transactionAsync.when(
        data: (transaction) {
          if (transaction == null) {
            return const Center(child: Text('Transaction not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transaction info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Transaction ID', style: Theme.of(context).textTheme.bodySmall),
                            Chip(
                              label: Text(transaction.status.name),
                              backgroundColor: transaction.status.name == 'COMPLETED'
                                  ? AppColors.success.withOpacity(0.2)
                                  : AppColors.warning.withOpacity(0.2),
                            ),
                          ],
                        ),
                        Text(transaction.transactionId, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        _InfoRow('Date', _formatDateTime(transaction.createdAt)),
                        _InfoRow('Device', transaction.deviceId),
                        if (transaction.customerName != null) _InfoRow('Customer', transaction.customerName!),
                        if (transaction.customerPhone != null) _InfoRow('Phone', transaction.customerPhone!),
                        const Divider(height: 24),
                        _InfoRow('Subtotal', Money.fromDouble(transaction.totalAmount + transaction.totalDiscount).format()),
                        if (transaction.totalDiscount > 0)
                          _InfoRow('Discount', '- ${Money.fromDouble(transaction.totalDiscount).format()}', color: AppColors.error),
                        _InfoRow('Total', Money.fromDouble(transaction.totalAmount).format(), isTotal: true),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Items
                Text('Items', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),

                linesAsync.when(
                  data: (lines) => Column(
                    children: lines.map((line) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(line.itemName ?? 'Unknown Item'),
                          subtitle: Text('Code: ${line.itemId} • Qty: ${line.quantity}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Money.fromDouble(line.lineTotal).format(),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (line.discount > 0)
                                Text(
                                  '${line.discountPercentage.toStringAsFixed(0)}% off',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text('Error: $error'),
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

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isTotal;

  const _InfoRow(this.label, this.value, {this.color, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : null,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: isTotal ? FontWeight.bold : null,
                  fontSize: isTotal ? 18 : null,
                ),
          ),
        ],
      ),
    );
  }
} */