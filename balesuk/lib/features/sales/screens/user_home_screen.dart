/* // ===================================================================
// COMPLETE SCREENS BUNDLE - ALL REMAINING SCREENS
// ===================================================================

// ===================================================================
// 1. USER HOME SCREEN
// lib/features/sales/screens/user_home_screen.dart
// ===================================================================

import 'package:balesuk/features/sales/providers/sales_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../providers/transaction_provider.dart';
import '../../../data/models/isar_models.dart';

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceConfigAsync = ref.watch(deviceConfigProvider);
    final shopAsync = ref.watch(shopNotifierProvider);

    return deviceConfigAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (deviceConfig) {
        if (deviceConfig == null || deviceConfig.mode != DeviceMode.USER) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return shopAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) => Scaffold(body: Center(child: Text('Error: $error'))),
          data: (shop) {
            if (shop == null || !shop.isOpen) {
              return _ShopClosedScreen();
            }

            return _UserHomeContent(
              deviceConfig: deviceConfig,
              shop: shop,
            );
          },
        );
      },
    );
  }
}

class _ShopClosedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Mode')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock, size: 80, color: AppColors.textTertiary),
            const SizedBox(height: 24),
            Text('Shop is Closed', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('Please wait for admin to open the shop'),
          ],
        ),
      ),
    );
  }
}

class _UserHomeContent extends ConsumerWidget {
  final deviceConfig;
  final shop;

  const _UserHomeContent({required this.deviceConfig, required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(todaysTransactionStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop.name),
            Text('User Mode - ${deviceConfig.deviceId}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop status
            Card(
              color: AppColors.success.withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.store, color: AppColors.success),
                title: const Text('Shop is Open'),
                subtitle: Text('Date: ${shop.currentShopOpenDate}'),
              ),
            ),
            const SizedBox(height: 16),

            // Today's stats
            statsAsync.when(
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Sales Today', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: Icons.receipt, label: 'Sales', value: '${stats.totalTransactions}', color: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(icon: Icons.attach_money, label: 'Amount', value: stats.totalSales.format(), color: AppColors.success)),
                    ],
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new-sale'),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Sale'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}


 */