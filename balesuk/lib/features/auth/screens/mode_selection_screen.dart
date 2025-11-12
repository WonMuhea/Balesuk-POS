import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../../data/database/isar_service.dart';
import '../../../data/models/isar_models.dart';

class ModeSelectionScreen extends ConsumerWidget with LoggerMixin {
  const ModeSelectionScreen({super.key});

  Future<void> _quickDevSetup(BuildContext context, WidgetRef ref) async {
    try {
      AppLogger.auth('Quick dev setup started');
      
      final isarService = IsarService.instance;
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Create shop
      final shop = Shop.create(
        shopId: 'SHOP001',
        name: 'Demo Shop (የምሳሌ ሱቅ)',
        familyDigits: 2,
        itemDigits: 4,
        createdAt: DateTime.now(),
        isOpen: true,
        currentShopOpenDate: today,
      );

      await isarService.saveShop(shop);
      AppLogger.database('Demo shop created', details: 'SHOP001');

      // Create device config
      final deviceConfig = DeviceConfig.create(
        deviceId: 'ADM001',
        shopId: 'SHOP001',
        mode: DeviceMode.ADMIN,
        isConfigured: true,
        currentTrxCounter: 1,
        currentShopOpenDate: today,
        createdAt: DateTime.now(),
      );

      await isarService.saveDeviceConfig(deviceConfig);
      AppLogger.database('Device config saved', details: 'ADM001 (ADMIN)');

      // Mark as configured
      await prefs.setBool('isConfigured', true);
      AppLogger.auth('Quick dev setup completed');

      // Refresh providers
      ref.invalidate(deviceConfigProvider);
      ref.invalidate(deviceConfigNotifierProvider);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Quick setup completed!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to inventory
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            context.go('/inventory');
          }
        });
      }
    } catch (e, stack) {
      AppLogger.error('Quick setup failed', error: e, stackTrace: stack);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo/icon
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // App title
              Text(
                AppStrings.appName,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Mobile POS System',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 64),
              
              // DEV: Quick Setup Button
              ElevatedButton.icon(
                onPressed: () => _quickDevSetup(context, ref),
                icon: const Icon(Icons.bolt),
                label: const Text('🔧 Quick Setup (Dev)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Welcome message
              Text(
                AppStrings.selectDeviceMode,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                AppStrings.modeSelectionDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Admin button
              _ModeCard(
                icon: Icons.admin_panel_settings,
                title: AppStrings.adminMode,
                description: AppStrings.adminModeDescription,
                color: AppColors.primary,
                onTap: () {
                  AppLogger.navigation('Navigating to admin setup');
                  context.push('/admin-setup');
                },
              ),
              
              const SizedBox(height: 16),
              
              // User button
              _ModeCard(
                icon: Icons.person,
                title: AppStrings.userMode,
                description: AppStrings.userModeDescription,
                color: AppColors.info,
                onTap: () {
                  AppLogger.navigation('Navigating to user setup');
                  context.push('/user-setup');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}