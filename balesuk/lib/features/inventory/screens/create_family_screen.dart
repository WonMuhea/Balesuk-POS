// lib/features/inventory/screens/create_family_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/result.dart'; // Import the Result type
import '../providers/inventory_provider.dart';

// --------------------------------------------------------------------------
// Helper function to calculate capacity (Moved out of the State class)
int _calculateCapacity(int itemDigits) {
  // Use a power function for accuracy if necessary, but 
  // keeping the bit shift for simplicity based on original code
  return (1 << (itemDigits * 4)) - 1; 
}

// Helper Chip remains outside the state class
class _ExampleChip extends StatelessWidget {
  final String label;
  const _ExampleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      labelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
      ),
    );
  }
}
// --------------------------------------------------------------------------

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  // NOTE: You must define a StateProvider or StateNotifierProvider 
  // (e.g., familyCreationProvider) in inventory_provider.dart to manage the
  // async state of this operation. For now, we'll keep the logic local but 
  // correct the flow.

  Future<void> _createFamily() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Set loading state (assuming a local StateProvider or AsyncNotifier manages this)
    // Here we'll manage it locally for simplicity, but the proper Riverpod way is
    // to update the notifier's state.
    final inventoryNotifier = ref.read(inventoryNotifierProvider.notifier);
    final deviceConfig = ref.read(currentDeviceConfigProvider)!;
    final shop = ref.read(currentShopProvider)!;
    
    // Instead of setState, we would trigger the notifier which handles the loading state.
    // Since this screen needs local control for the button spinner, we keep the setState.
    setState(() {}); // Reset state before operation (optional)

    final result = await inventoryNotifier.createFamily(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        shopId: deviceConfig.shopId,
        familyDigits: shop.familyDigits,
    );

    if (!mounted) return;

    // --- CRITICAL CORRECTION: Handle the Result type ---
    result.when(
      success: (family) {
        // Success case
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Family "${family.name}" created! (Code: ${family.familyCode})',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Invalidate families provider to refresh list
        ref.invalidate(itemFamiliesProvider);
        ref.invalidate(inventoryStatsProvider);

        context.pop();
      },
      error: (failure) {
        // Error case: The failure contains the localized message/key
        // You would use your localization service here. For now, display the message.
        final errorMessage = failure.message ?? 'An unknown creation error occurred.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create family: $errorMessage'),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );

    // Stop loading (Since we didn't fully move loading to a notifier, we set it back here)
    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    // 1. Correctly read the Provider values (using the helper providers)
    final deviceConfig = ref.watch(currentDeviceConfigProvider); 
    final shop = ref.watch(currentShopProvider);
    
    // 2. Determine loading state by reading the notifier's state if possible,
    // otherwise, we use a manual flag or a dedicated provider for this action's status.
    final inventoryState = ref.watch(inventoryNotifierProvider);
    final bool isCreating = inventoryState.isCreatingFamily; // Assuming this flag exists

    if (deviceConfig == null || shop == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Item Family'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                color: AppColors.info.withAlpha((255 * 0.1).round()),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item Family',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            // Use shop.itemDigits directly as it's non-nullable in shop entity
                            Text(
                              'A family is a category of items (e.g., Electronics, Clothing). Each family can have up to ${_calculateCapacity(shop.itemDigits)} items.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Family name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Family Name *',
                  prefixIcon: Icon(Icons.category),
                  hintText: 'e.g., Electronics',
                  helperText: 'Choose a clear category name',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter family name'; // Should use localized key
                  }
                  if (value.length < 3) {
                    return 'Name must be at least 3 characters'; // Should use localized key
                  }
                  if (value.length > 50) {
                    return 'Name must be less than 50 characters'; // Should use localized key
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description),
                  hintText: 'Brief description of this category',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value != null && value.length > 200) {
                    return 'Description must be less than 200 characters'; // Should use localized key
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Examples card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Family Examples',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap( // Using Wrap for better layout than Column
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: const [
                          _ExampleChip(label: 'Electronics'),
                          _ExampleChip(label: 'Clothing'),
                          _ExampleChip(label: 'Food & Beverages'),
                          _ExampleChip(label: 'Home & Garden'),
                          _ExampleChip(label: 'Sports & Outdoors'),
                        ],
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Create button
              ElevatedButton(
                // Use the derived loading state here
                onPressed: isCreating ? null : _createFamily, 
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Create Family',
                        style: TextStyle(fontSize: 16),
                      ),
              ),

              const SizedBox(height: 16),

              // Cancel button
              OutlinedButton(
                onPressed: isCreating ? null : () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}