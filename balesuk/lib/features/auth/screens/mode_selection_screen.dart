// lib/features/auth/screens/mode_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/database/isar_service.dart';
import '../../../data/models/isar_models.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  Future<void> _quickDevSetup(BuildContext context) async {
    try {
      final isarService = IsarService.instance;
      final prefs = await SharedPreferences.getInstance();

      // Create device config
      final deviceConfig = DeviceConfig.create(
        deviceId: 'ADM001',
        shopId: 'SHOP001',
        mode: DeviceMode.ADMIN,
        isConfigured: true,
        currentTrxCounter: 1,
        currentShopOpenDate: DateTime.now().toIso8601String().substring(0, 10),
        createdAt: DateTime.now(),
      );

      await isarService.saveDeviceConfig(deviceConfig);

      // Create shop
      final shop = Shop.create(
        shopId: 'SHOP001',
        name: 'የምሳሌ ሱቅ',
        familyDigits: 2,
        itemDigits: 4,
        createdAt: DateTime.now(),
        isOpen: true,
        currentShopOpenDate: DateTime.now().toIso8601String().substring(0, 10),
      );

      await isarService.saveShop(shop);

      // Mark as configured
      await prefs.setBool('isConfigured', true);

      // Navigate to admin home
      if (context.mounted) {
        context.go('/admin-home');
      }
    } catch (e) {
      print('Setup error: $e');
    }
  }
    @override
  Widget build(BuildContext context) {
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
              
              // DEV: Quick Setup Button (ADD THIS FIRST)
              ElevatedButton.icon(
                onPressed: () => _quickDevSetup(context),
                icon: const Icon(Icons.bolt),
                label: const Text('🔧 Quick Setup & Go to Inventory'),
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
                style: Theme.of(context).textTheme.bodyMedium,
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
            offset: const Offset(0, 2),
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