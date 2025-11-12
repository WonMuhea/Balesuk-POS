import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import screens (placeholders - will be created)
import '../../features/auth/screens/mode_selection_screen.dart';
import '../../features/auth/screens/admin_setup_screen.dart';
import '../../features/auth/screens/user_setup_screen.dart';
import '../../features/sales/screens/admin_home_screen.dart';
import '../../features/sales/screens/user_home_screen.dart';
import '../../features/shop/screens/open_shop_screen.dart';
import '../../features/inventory/screens/inventory_management_screen.dart';
import '../../features/inventory/screens/create_family_screen.dart';
import '../../features/inventory/screens/create_item_screen.dart';
import '../../features/inventory/screens/item_detail_screen.dart';
import '../../features/inventory/screens/bulk_item_creation_screen.dart';
import '../../features/sales/screens/new_sale_screen.dart';
import '../../features/sales/screens/transaction_list_screen.dart';
import '../../features/sales/screens/transaction_detail_screen.dart';
import '../../features/sync/screens/sync_screen.dart';
import '../../features/sync/screens/sync_history_screen.dart';

import '../../data/models/isar_models.dart';
import '../providers/providers.dart';

// ==================== ROUTE NAMES ====================

class AppRoutes {
  // Auth routes
  static const modeSelection = '/';
  static const adminSetup = '/admin-setup';
  static const userSetup = '/user-setup';
  
  // Home routes
  static const adminHome = '/admin-home';
  static const userHome = '/user-home';
  
  // Shop routes
  static const openShop = '/open-shop';
  
  // Inventory routes
  static const inventory = '/inventory';
  static const createFamily = '/inventory/create-family';
  static const createItem = '/inventory/create-item';
  static const bulkCreateItems = '/inventory/bulk-create-items';
  static const itemDetail = '/inventory/item/:itemId';
  
  // Sales routes
  static const newSale = '/new-sale';
  static const transactions = '/transactions';
  static const transactionDetail = '/transactions/:transactionId';
  
  // Sync routes
  static const sync = '/sync';
  static const syncHistory = '/sync/history';
}

// ==================== ROUTER PROVIDER ====================

final routerProvider = Provider<GoRouter>((ref) {
  final deviceConfigNotifier = ref.watch(deviceConfigNotifierProvider);
  
  return GoRouter(
    initialLocation: AppRoutes.modeSelection,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final deviceConfig = deviceConfigNotifier.value;
      final currentPath = state.uri.path;
      
      // If device not configured and not on setup screens, go to mode selection
      if (deviceConfig == null) {
        if (currentPath != AppRoutes.modeSelection &&
            currentPath != AppRoutes.adminSetup &&
            currentPath != AppRoutes.userSetup) {
          return AppRoutes.modeSelection;
        }
        return null;
      }
      
      // Device is configured
      if (currentPath == AppRoutes.modeSelection ||
          currentPath == AppRoutes.adminSetup ||
          currentPath == AppRoutes.userSetup) {
        // Already configured, redirect to appropriate home
        return deviceConfig.mode == DeviceMode.ADMIN 
            ? AppRoutes.adminHome 
            : AppRoutes.userHome;
      }
      
      return null;
    },
    routes: [
      // ==================== AUTH ROUTES ====================
      GoRoute(
        path: AppRoutes.modeSelection,
        name: 'mode-selection',
        builder: (context, state) => const ModeSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminSetup,
        name: 'admin-setup',
        builder: (context, state) => const AdminSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.userSetup,
        name: 'user-setup',
        builder: (context, state) => const UserSetupScreen(),
      ),
      
      // ==================== HOME ROUTES ====================
      /* GoRoute(
        path: AppRoutes.adminHome,
        name: 'admin-home',
        builder: (context, state) => const AdminHomeScreen(),
      ), */
      /* GoRoute(
        path: AppRoutes.userHome,
        name: 'user-home',
        builder: (context, state) => const UserHomeScreen(),
      ),
       */
      // ==================== SHOP ROUTES ====================
     /*  GoRoute(
        path: AppRoutes.openShop,
        name: 'open-shop',
        builder: (context, state) => const OpenShopScreen(),
      ),
       */
      // ==================== INVENTORY ROUTES ====================
      GoRoute(
        path: AppRoutes.inventory,
        name: 'inventory',
        builder: (context, state) => const InventoryManagementScreen(),
        routes: [
          GoRoute(
            path: 'create-family',
            name: 'create-family',
            builder: (context, state) => const CreateFamilyScreen(),
          ),
          GoRoute(
            path: 'create-item',
            name: 'create-item',
            builder: (context, state) {
              final familyId = state.uri.queryParameters['familyId'];
              return CreateItemScreen(familyId: familyId);
            },
          ),
          /* GoRoute(
            path: 'bulk-create-items',
            name: 'bulk-create-items',
            builder: (context, state) {
              final familyId = state.uri.queryParameters['familyId'] ?? '';
              return BulkItemCreationScreen(familyId: familyId);
            },
          ),
          GoRoute(
            path: 'item/:itemId',
            name: 'item-detail',
            builder: (context, state) {
              final itemId = state.pathParameters['itemId']!;
              return ItemDetailScreen(itemId: itemId);
            },
          ), */
        ],
      ),
      
      // ==================== SALES ROUTES ====================
      GoRoute(
        path: AppRoutes.newSale,
        name: 'new-sale',
        builder: (context, state) {
          final isAdmin = state.uri.queryParameters['isAdmin'] == 'true';
          return NewSaleScreen(isAdmin: isAdmin);
        },
      ),
      /* GoRoute(
        path: AppRoutes.transactions,
        name: 'transactions',
        builder: (context, state) => const TransactionListScreen(),
        routes: [
          GoRoute(
            path: ':transactionId',
            name: 'transaction-detail',
            builder: (context, state) {
              final transactionId = state.pathParameters['transactionId']!;
              return TransactionDetailScreen(transactionId: transactionId);
            },
          ),
        ],
      ), */
      
      // ==================== SYNC ROUTES ====================
      GoRoute(
        path: AppRoutes.sync,
        name: 'sync',
        builder: (context, state) => const SyncScreen(),
        routes: [
          GoRoute(
            path: 'history',
            name: 'sync-history',
            builder: (context, state) => const SyncHistoryScreen(),
          ),
        ],
      ),
    ],
    
    // Error handling
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.modeSelection),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

// ==================== NAVIGATION EXTENSIONS ====================

extension NavigationExtension on BuildContext {
  // Auth navigation
  void goToModeSelection() => go(AppRoutes.modeSelection);
  void goToAdminSetup() => go(AppRoutes.adminSetup);
  void goToUserSetup() => go(AppRoutes.userSetup);
  
  // Home navigation
  void goToAdminHome() => go(AppRoutes.adminHome);
  void goToUserHome() => go(AppRoutes.userHome);
  
  // Shop navigation
  void goToOpenShop() => push(AppRoutes.openShop);
  
  // Inventory navigation
  void goToInventory() => push(AppRoutes.inventory);
  void goToCreateFamily() => push(AppRoutes.createFamily);
  void goToCreateItem({String? familyId}) {
    final uri = Uri(
      path: AppRoutes.createItem,
      queryParameters: familyId != null ? {'familyId': familyId} : null,
    );
    push(uri.toString());
  }
  void goToBulkCreateItems(String familyId) {
    push('${AppRoutes.bulkCreateItems}?familyId=$familyId');
  }
  void goToItemDetail(String itemId) {
    push(AppRoutes.itemDetail.replaceAll(':itemId', itemId));
  }
  
  // Sales navigation
  void goToNewSale({required bool isAdmin}) {
    push('${AppRoutes.newSale}?isAdmin=$isAdmin');
  }
  void goToTransactions() => push(AppRoutes.transactions);
  void goToTransactionDetail(String transactionId) {
    push(AppRoutes.transactionDetail.replaceAll(':transactionId', transactionId));
  }
  
  // Sync navigation
  void goToSync() => push(AppRoutes.sync);
  void goToSyncHistory() => push(AppRoutes.syncHistory);
}