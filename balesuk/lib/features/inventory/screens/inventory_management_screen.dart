import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/providers/providers.dart';
import '../providers/inventory_provider.dart';
import '../widgets/inventory_stats_card.dart';

class InventoryManagementScreen extends ConsumerStatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  ConsumerState<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState
    extends ConsumerState<InventoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final deviceConfig = ref.watch(deviceConfigProvider).value;
    
    if (deviceConfig == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final statsAsync = ref.watch(inventoryStatsProvider(deviceConfig.shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.inventoryManagement),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(inventoryProvider.notifier).loadFamilies();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(inventoryProvider.notifier).loadFamilies();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    ref.read(inventoryProvider.notifier).searchItems(value);
                  },
                  decoration: InputDecoration(
                    hintText: AppStrings.searchFamiliesOrItems,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textTertiary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(inventoryProvider.notifier).searchItems('');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Stats cards
              statsAsync.when(
                data: (stats) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InventoryStatsCard(
                          icon: Icons.category_outlined,
                          label: AppStrings.totalFamilies,
                          value: stats['totalFamilies'].toString(),
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InventoryStatsCard(
                          icon: Icons.inventory_2_outlined,
                          label: AppStrings.totalItems,
                          value: stats['totalItems'].toString(),
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InventoryStatsCard(
                          icon: Icons.warning_outlined,
                          label: AppStrings.lowStock,
                          value: stats['lowStockCount'].toString(),
                          color: stats['lowStockCount'] > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.push('/inventory/create-family');
                        },
                        icon: const Icon(Icons.group_add, size: 20),
                        label: Text(AppStrings.addFamily),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/inventory/create-item');
                        },
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                        label: Text(AppStrings.addItem),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Families list or items search results
              if (inventoryState.searchQuery.isEmpty)
                _buildFamiliesList(inventoryState)
              else
                _buildSearchResults(inventoryState),

              const SizedBox(height: 16),

              // Last sync info
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${AppStrings.lastSync}: 15 minutes ago',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.refresh,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamiliesList(InventoryState state) {
    if (state.isLoading && state.families.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.families.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: AppColors.textTertiary.withAlpha((255 * 0.5).round()),
              ),
              const SizedBox(height: 16),
              const Text(
                'ምንም ቤተሰቦች የሉም',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ቤተሰብ ለመፍጠር "ቤተሰብ አክል" የሚለውን ይጫኑ',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: state.families.map((family) {
          return FutureBuilder<int>(
            future: ref.read(isarServiceProvider).getFamilyItemCount(family.familyId),
            builder: (context, snapshot) {
              final itemCount = snapshot.data ?? 0;
              return FamilyCard(
                name: family.name,
                code: family.familyId,
                itemCount: itemCount,
                icon: _getFamilyIcon(family.name),
                onTap: () {
                  context.push('/inventory/create-item?familyId=${family.familyId}');
                },
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchResults(InventoryState state) {
    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: AppColors.textTertiary.withAlpha((255 * 0.5).round()),
              ),
              const SizedBox(height: 16),
              const Text(
                'ምንም ውጤት አልተገኘም',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              '${state.items.length} እቃዎች ተገኝተዋል',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...state.items.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildItemCard(item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/inventory/item/${item.itemId}');
          },
          borderRadius: BorderRadius.circular(16),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (item.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppStrings.lowStock,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${AppStrings.itemId}: ${item.itemId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.priceAsMoney.format(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppStrings.quantity}: ${item.quantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFamilyIcon(String familyName) {
    final name = familyName.toLowerCase();
    if (name.contains('electronic') || name.contains('ኤሌክትሮኒክስ')) {
      return Icons.laptop;
    } else if (name.contains('cloth') || name.contains('ልብስ')) {
      return Icons.checkroom;
    } else if (name.contains('drink') || name.contains('መጠጥ')) {
      return Icons.local_drink;
    } else if (name.contains('food') || name.contains('ምግብ')) {
      return Icons.restaurant;
    }
    return Icons.category;
  }
}