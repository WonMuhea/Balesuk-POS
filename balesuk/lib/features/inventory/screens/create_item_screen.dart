import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/money.dart';
import '../../../ui/common/app_dialogs.dart';
import '../providers/inventory_provider.dart';
import '../../../data/models/isar_models.dart';

class CreateItemScreen extends ConsumerStatefulWidget {
  final String? familyId;

  const CreateItemScreen({super.key, this.familyId});

  @override
  ConsumerState<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends ConsumerState<CreateItemScreen>
    with LoggerMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minQuantityController = TextEditingController();

  String? _selectedFamilyId;
  List<AttributeDefinition> _attributeDefinitions = [];
  final Map<int, dynamic> _attributeValues = {};
  final Map<int, TextEditingController> _attributeControllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedFamilyId = widget.familyId;
    if (_selectedFamilyId != null) {
      _loadAttributes();
    }
  }

  Future<void> _loadAttributes() async {
    if (_selectedFamilyId == null) return;

    final attrs = await ref
        .read(isarServiceProvider)
        .getAttributesByFamily(_selectedFamilyId!);

    setState(() {
      _attributeDefinitions = attrs;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    for (var controller in _attributeControllers.values) {
      controller.dispose();
    }
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.createItem),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Family Selection
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.family,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedFamilyId,
                      decoration: const InputDecoration(
                        hintText: 'ቤተሰብ ይምረጡ',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: inventoryState.families.map((family) {
                        return DropdownMenuItem(
                          value: family.familyId,
                          child: Text(family.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFamilyId = value;
                        });
                        _loadAttributes();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppStrings.fieldRequired(AppStrings.family);
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Item Name
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.itemName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'ለምሳሌ: ሰማያዊ ቲሸርት',
                        prefixIcon: Icon(Icons.shopping_bag),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppStrings.fieldRequired(AppStrings.itemName);
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Price and Quantity Row
              Row(
                children: [
                  Expanded(
                    child: _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.price,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              prefixText: 'ብር ',
                              prefixIcon: Icon(Icons.attach_money),
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
                              if (value == null || value.trim().isEmpty) {
                                return AppStrings.fieldRequired(AppStrings.price);
                              }
                              final price = double.tryParse(value);
                              if (price == null || price <= 0) {
                                return 'ዋጋ ከ 0 በላይ መሆን አለበት';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.quantity,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              hintText: '0',
                              prefixIcon: Icon(Icons.inventory),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return AppStrings.fieldRequired(AppStrings.quantity);
                              }
                              final qty = int.tryParse(value);
                              if (qty == null || qty < 0) {
                                return 'ልክ ያልሆነ';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Min Quantity
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.minQuantity,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ዝቅተኛ የአቅርቦት ማስጠንቀቂያ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _minQuantityController,
                      decoration: const InputDecoration(
                        hintText: '0',
                        prefixIcon: Icon(Icons.warning_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppStrings.fieldRequired(AppStrings.minQuantity);
                        }
                        final minQty = int.tryParse(value);
                        if (minQty == null || minQty < 0) {
                          return 'ልክ ያልሆነ';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // Attributes
              if (_attributeDefinitions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.attributes,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._attributeDefinitions.map((attr) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildAttributeField(attr),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(AppStrings.save),
              ),
            ],
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAttributeField(AttributeDefinition attr) {
    switch (attr.dataType) {
      case AttributeDataType.TEXT:
        return TextFormField(
          decoration: InputDecoration(
            labelText: '${attr.name}${attr.isRequired ? ' *' : ''}',
          ),
          onChanged: (value) {
            _attributeValues[attr.id] = value;
          },
          validator: attr.isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppStrings.fieldRequired(attr.name);
                  }
                  return null;
                }
              : null,
        );

      case AttributeDataType.NUMBER:
        return TextFormField(
          decoration: InputDecoration(
            labelText: '${attr.name}${attr.isRequired ? ' *' : ''}',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          onChanged: (value) {
            _attributeValues[attr.id] = double.tryParse(value);
          },
          validator: attr.isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppStrings.fieldRequired(attr.name);
                  }
                  return null;
                }
              : null,
        );

      case AttributeDataType.DROPDOWN:
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: '${attr.name}${attr.isRequired ? ' *' : ''}',
          ),
          items: attr.dropdownOptions?.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (value) {
            _attributeValues[attr.id] = value;
          },
          validator: attr.isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return AppStrings.fieldRequired(attr.name);
                  }
                  return null;
                }
              : null,
        );

      case AttributeDataType.BOOLEAN:
        return CheckboxListTile(
          title: Text(attr.name),
          value: _attributeValues[attr.id] as bool? ?? false,
          onChanged: (value) {
            setState(() {
              _attributeValues[attr.id] = value ?? false;
            });
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        );

      case AttributeDataType.DATE:
        if (!_attributeControllers.containsKey(attr.id)) {
          _attributeControllers[attr.id] = TextEditingController();
        }
        return TextFormField(
          decoration: InputDecoration(
            labelText: '${attr.name}${attr.isRequired ? ' *' : ''}',
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          readOnly: true,
          controller: _attributeControllers[attr.id],
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() {
                _attributeValues[attr.id] = date;
                _attributeControllers[attr.id]!.text = 
                    date.toIso8601String().substring(0, 10);
              });
            }
          },
          validator: attr.isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppStrings.fieldRequired(attr.name);
                  }
                  return null;
                }
              : null,
        );
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFamilyId == null) {
      await AppDialogs.showError(
        context,
        message: AppStrings.fieldRequired(AppStrings.family),
      );
      return;
    }

    logInfo('Saving item: ${_nameController.text}');

    setState(() {
      _isLoading = true;
    });

    try {
      final deviceConfig = ref.read(deviceConfigProvider).value!;
      final shop = await ref.read(isarServiceProvider).getShop(deviceConfig.shopId);

      if (shop == null) {
        throw Exception('Shop not found');
      }

      final price = Money.fromDouble(double.parse(_priceController.text));

      final error = await ref.read(inventoryProvider.notifier).createItem(
        familyId: _selectedFamilyId!,
        name: _nameController.text.trim(),
        price: price,
        quantity: int.parse(_quantityController.text),
        minQuantity: int.parse(_minQuantityController.text),
        familyDigits: shop.familyDigits,
        itemDigits: shop.itemDigits,
        attributeValues: _attributeValues.isNotEmpty ? _attributeValues : null,
      );

      if (error != null) {
        throw Exception(error);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        await AppDialogs.showSuccess(
          context,
          message: AppStrings.itemSavedSuccess,
          onDismiss: () {
            context.pop();
          },
        );
      }
    } catch (e, stack) {
      logError('Failed to save item', error: e, stackTrace: stack);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        await AppDialogs.showError(
          context,
          message: e.toString(),
        );
      }
    }
  }
}