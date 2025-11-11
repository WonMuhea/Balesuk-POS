import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../../ui/common/app_dialogs.dart';
import '../providers/inventory_provider.dart';
import '../../../data/models/isar_models.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen>
    with LoggerMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final List<AttributeDefinitionInput> _attributes = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceConfig = ref.watch(deviceConfigProvider).value;
    
    if (deviceConfig == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.createFamily),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Family Name
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.familyName,
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
                        hintText: 'ለምሳሌ: ኤሌክትሮኒክስ',
                        prefixIcon: Icon(Icons.category),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppStrings.fieldRequired(AppStrings.familyName);
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Family Description
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.familyDescription,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: '${AppStrings.optional} - መግለጫ',
                        prefixIcon: const Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Attributes Section
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.attributes,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addAttribute,
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(AppStrings.addAttribute),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (_attributes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'ምንም ባህሪያት አልተጨመሩም',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._attributes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final attr = entry.value;
                        return _buildAttributeItem(attr, index);
                      }).toList(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveFamily,
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
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAttributeItem(AttributeDefinitionInput attr, int index) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  attr.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                color: AppColors.error,
                onPressed: () => _removeAttribute(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_getDataTypeLabel(attr.dataType)}${attr.isRequired ? ' • ${AppStrings.required}' : ''}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _addAttribute() {
    showDialog(
      context: context,
      builder: (context) => _AttributeDialog(
        onSave: (attr) {
          setState(() {
            _attributes.add(attr);
          });
        },
      ),
    );
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes.removeAt(index);
    });
  }

  Future<void> _saveFamily() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    logInfo('Saving family: ${_nameController.text}');

    setState(() {
      _isLoading = true;
    });

    try {
      final deviceConfig = ref.read(deviceConfigProvider).value!;
      final shop = await ref.read(isarServiceProvider).getShop(deviceConfig.shopId);
      
      if (shop == null) {
        throw Exception('Shop not found');
      }

      // Create family
      final error = await ref.read(inventoryProvider.notifier).createFamily(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        familyDigits: shop.familyDigits,
      );

      if (error != null) {
        throw Exception(error);
      }

      // Save attributes if any
      if (_attributes.isNotEmpty) {
        // Get the newly created family
        final families = await ref.read(isarServiceProvider)
            .getAllFamilies(deviceConfig.shopId);
        final newFamily = families.lastWhere(
          (f) => f.name == _nameController.text.trim(),
        );

        // Save attribute definitions
        final attributeDefs = _attributes.asMap().entries.map((entry) {
          return AttributeDefinition.create(
            familyId: newFamily.familyId,
            name: entry.value.name,
            dataType: entry.value.dataType,
            isRequired: entry.value.isRequired,
            dropdownOptions: entry.value.dropdownOptions,
            displayOrder: entry.key,
            createdAt: DateTime.now(),
          );
        }).toList();

        await ref.read(isarServiceProvider)
            .saveMultipleAttributeDefinitions(attributeDefs);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        await AppDialogs.showSuccess(
          context,
          message: AppStrings.familySavedSuccess,
          onDismiss: () {
            context.pop();
          },
        );
      }
    } catch (e, stack) {
      logError('Failed to save family', error: e, stackTrace: stack);
      
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

  String _getDataTypeLabel(AttributeDataType type) {
    switch (type) {
      case AttributeDataType.TEXT:
        return 'ጽሑፍ';
      case AttributeDataType.NUMBER:
        return 'ቁጥር';
      case AttributeDataType.DATE:
        return 'ቀን';
      case AttributeDataType.BOOLEAN:
        return 'አዎ/አይ';
      case AttributeDataType.DROPDOWN:
        return 'ምርጫ';
    }
  }
}

// ==================== ATTRIBUTE DEFINITION INPUT ====================

class AttributeDefinitionInput {
  final String name;
  final AttributeDataType dataType;
  final bool isRequired;
  final List<String>? dropdownOptions;

  AttributeDefinitionInput({
    required this.name,
    required this.dataType,
    required this.isRequired,
    this.dropdownOptions,
  });
}

// ==================== ATTRIBUTE DIALOG ====================

class _AttributeDialog extends StatefulWidget {
  final Function(AttributeDefinitionInput) onSave;

  const _AttributeDialog({required this.onSave});

  @override
  State<_AttributeDialog> createState() => _AttributeDialogState();
}

class _AttributeDialogState extends State<_AttributeDialog> {
  final _nameController = TextEditingController();
  final _optionsController = TextEditingController();
  AttributeDataType _selectedType = AttributeDataType.TEXT;
  bool _isRequired = false;

  @override
  void dispose() {
    _nameController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.addAttribute,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            
            // Attribute Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppStrings.attributeName,
                hintText: 'ለምሳሌ: መጠን',
              ),
            ),
            const SizedBox(height: 16),
            
            // Data Type
            DropdownButtonFormField<AttributeDataType>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: AppStrings.attributeType,
              ),
              items: AttributeDataType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getDataTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Dropdown Options (if DROPDOWN type)
            if (_selectedType == AttributeDataType.DROPDOWN)
              TextFormField(
                controller: _optionsController,
                decoration: const InputDecoration(
                  labelText: 'ምርጫዎች',
                  hintText: 'በኮማ ተለይተው: ትንሽ, መካከለኛ, ትልቅ',
                ),
                maxLines: 2,
              ),
            
            const SizedBox(height: 16),
            
            // Required Checkbox
            CheckboxListTile(
              value: _isRequired,
              onChanged: (value) {
                setState(() {
                  _isRequired = value ?? false;
                });
              },
              title: Text(AppStrings.required),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            
            const SizedBox(height: 20),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(AppStrings.add),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      return;
    }

    List<String>? options;
    if (_selectedType == AttributeDataType.DROPDOWN) {
      options = _optionsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      
      if (options.isEmpty) {
        return;
      }
    }

    widget.onSave(
      AttributeDefinitionInput(
        name: _nameController.text.trim(),
        dataType: _selectedType,
        isRequired: _isRequired,
        dropdownOptions: options,
      ),
    );

    Navigator.pop(context);
  }

  String _getDataTypeLabel(AttributeDataType type) {
    switch (type) {
      case AttributeDataType.TEXT:
        return 'ጽሑፍ';
      case AttributeDataType.NUMBER:
        return 'ቁጥር';
      case AttributeDataType.DATE:
        return 'ቀን';
      case AttributeDataType.BOOLEAN:
        return 'አዎ/አይ';
      case AttributeDataType.DROPDOWN:
        return 'ምርጫ';
    }
  }
}