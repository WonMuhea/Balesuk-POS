// lib/features/inventory/screens/create_item_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../providers/inventory_provider.dart';
import '../../../core/utils/money.dart';

class CreateItemScreen extends ConsumerStatefulWidget {
  final int? familyCode;

  const CreateItemScreen({super.key, this.familyCode});

  @override
  ConsumerState<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends ConsumerState<CreateItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minQuantityController = TextEditingController();
  
  int? _selectedFamilyCode;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedFamilyCode = widget.familyCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceConfig = ref.watch(deviceConfigProvider).value;
    final familiesAsync = ref.watch(itemFamiliesProvider);

    if (deviceConfig == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Item'),
      ),
      body: familiesAsync.when(
        data: (families) {
          if (families.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  const Text('No Families Available'),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a family first before adding items',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/inventory/create-family'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Family'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Family selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Item Family',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _selectedFamilyCode,
                            decoration: const InputDecoration(
                              labelText: 'Select Family *',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: families.map((family) {
                              return DropdownMenuItem(
                                value: family.familyCode,
                                child: Text(
                                  '${family.familyId} - ${family.name}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedFamilyCode = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a family';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Basic info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Item Name *',
                              prefixIcon: Icon(Icons.inventory_2),
                              hintText: 'e.g., iPhone 15 Pro',
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter item name';
                              }
                              if (value.length < 3) {
                                return 'Name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              prefixIcon: Icon(Icons.attach_money),
                              prefixText: 'ETB ',
                              hintText: '0.00',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'),
                              ),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter price';
                              }
                              final price = double.tryParse(value);
                              if (price == null || price <= 0) {
                                return 'Please enter valid price';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stock info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stock Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Initial Quantity *',
                              prefixIcon: Icon(Icons.numbers),
                              hintText: '0',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter quantity';
                              }
                              final qty = int.tryParse(value);
                              if (qty == null || qty < 0) {
                                return 'Please enter valid quantity';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _minQuantityController,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Stock Level *',
                              prefixIcon: Icon(Icons.warning_amber),
                              hintText: '0',
                              helperText: 'Alert when stock falls below this',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter minimum quantity';
                              }
                              final minQty = int.tryParse(value);
                              if (minQty == null || minQty < 0) {
                                return 'Please enter valid quantity';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status
                  Card(
                    child: SwitchListTile(
                      title: const Text('Active Item'),
                      subtitle: const Text(
                        'Inactive items cannot be sold',
                      ),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() => _isActive = value);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Create button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createItem,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
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
                            'Create Item',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(itemFamiliesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFamilyCode == null) {
      _showError('Please select a family');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceConfig = ref.read(deviceConfigProvider).value!;
      final shop = ref.read(shopNotifierProvider).value!;

      // Create item using provider
      await ref.read(inventoryNotifierProvider.notifier).createItem(
            familyCode: _selectedFamilyCode!,
            name: _nameController.text.trim(),
            price: Money(double.parse(_priceController.text)),
            quantity: int.parse(_quantityController.text),
            minQuantity: int.parse(_minQuantityController.text),
            isActive: _isActive,
            shopId: deviceConfig.shopId,
            itemDigits: shop.itemDigits,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Invalidate relevant providers
        ref.invalidate(familyItemsProvider(_selectedFamilyCode!));
        ref.invalidate(inventoryStatsProvider);

        context.pop();
      }
    } catch (e) {
      _showError('Failed to create item: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}