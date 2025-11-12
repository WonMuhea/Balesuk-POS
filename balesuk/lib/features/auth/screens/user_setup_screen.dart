import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../../data/database/isar_service.dart';
import '../../../data/models/isar_models.dart';

class UserSetupScreen extends ConsumerStatefulWidget {
  const UserSetupScreen({super.key});

  @override
  ConsumerState<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends ConsumerState<UserSetupScreen> with LoggerMixin {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _shopIdController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _shopIdController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final deviceId = _deviceIdController.text.trim().toUpperCase();
      final shopId = _shopIdController.text.trim().toUpperCase();

      logInfo('Starting user setup for device: $deviceId, shop: $shopId');
      AppLogger.auth('User setup initiated', details: 'Device: $deviceId, Shop: $shopId');

      final isarService = IsarService.instance;
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Check if shop exists
      final shop = await isarService.getShop(shopId);
      if (shop == null) {
        logError('Shop not found: $shopId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shop $shopId not found. Please check with admin.'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      logInfo('Shop found: ${shop.name}');

      // Create device config
      final deviceConfig = DeviceConfig.create(
        deviceId: deviceId,
        shopId: shopId,
        mode: DeviceMode.USER,
        isConfigured: true,
        currentTrxCounter: 1,
        currentShopOpenDate: today,
        createdAt: DateTime.now(),
      );

      await isarService.saveDeviceConfig(deviceConfig);
      logSuccess('Device configured: $deviceId (USER)');
      AppLogger.database('Device config saved', details: 'ID: $deviceId, Mode: USER');

      // Mark as configured in shared preferences
      await prefs.setBool('isConfigured', true);
      logSuccess('Setup completed successfully');
      AppLogger.auth('User setup completed', details: 'Device: $deviceId');

      // Refresh the device config provider
      ref.invalidate(deviceConfigProvider);
      ref.invalidate(deviceConfigNotifierProvider);

      // Navigate to user home
      if (mounted) {
        context.go('/user-home');
      }
    } catch (e, stack) {
      logError('Setup failed', error: e, stackTrace: stack);
      AppLogger.error('User setup failed', error: e, stackTrace: stack);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.userSetup),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 48,
                    color: AppColors.info,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  AppStrings.userSetup,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                const Text(
                  'Configure this device as a user terminal',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Icon(
                        Icons.info_outline,
                        color: AppColors.info,
                        size: 24,
                      ),
                       SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:  [
                            Text(
                              'Note',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.info,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Please ensure the shop has been created by the admin device first.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Device ID
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.deviceId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _deviceIdController,
                        decoration: InputDecoration(
                          hintText: 'USR001',
                          prefixIcon: const Icon(Icons.devices),
                          helperText: 'Unique identifier for this device',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppStrings.fieldRequired(AppStrings.deviceId);
                          }
                          if (value.length < 3) {
                            return 'Device ID must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Shop ID
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.shopId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _shopIdController,
                        decoration: const InputDecoration(
                          hintText: 'SHOP001',
                          prefixIcon: Icon(Icons.store),
                          helperText: 'Shop ID from admin device',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppStrings.fieldRequired(AppStrings.shopId);
                          }
                          if (value.length < 3) {
                            return 'Shop ID must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Complete Setup Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _completeSetup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.info,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          AppStrings.completeSetup,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}