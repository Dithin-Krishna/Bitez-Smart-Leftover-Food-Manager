import 'dart:io';
import 'package:flutter/material.dart';
import '../services/food_recognition_service.dart';

/// Phase 5 – User Confirmation Dialog
/// Allows users to review, modify quantities, edit food names, reject non-food predictions,
/// and confirm items before saving to MongoDB Virtual Fridge (Phase 6).
class FoodConfirmationDialog extends StatefulWidget {
  final File imageFile;
  final List<RecognizedFoodItem> detectedItems;

  const FoodConfirmationDialog({
    super.key,
    required this.imageFile,
    required this.detectedItems,
  });

  static Future<List<RecognizedFoodItem>?> show(
    BuildContext context, {
    required File imageFile,
    required List<RecognizedFoodItem> detectedItems,
  }) {
    return showDialog<List<RecognizedFoodItem>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FoodConfirmationDialog(
        imageFile: imageFile,
        detectedItems: detectedItems,
      ),
    );
  }

  @override
  State<FoodConfirmationDialog> createState() => _FoodConfirmationDialogState();
}

class _FoodConfirmationDialogState extends State<FoodConfirmationDialog> {
  late List<RecognizedFoodItem> _items;

  @override
  void initState() {
    super.initState();
    // Clone list to allow inline editing
    _items = widget.detectedItems.map((item) {
      return RecognizedFoodItem(
        label: item.label,
        category: item.category,
        section: item.section,
        emoji: item.emoji,
        qty: item.qty,
        isSelected: item.isSelected,
        isValidated: item.isValidated,
      );
    }).toList();
  }

  void _addNewItem() {
    setState(() {
      _items.add(
        RecognizedFoodItem(
          label: 'New Food Item',
          category: 'Vegetables',
          section: 'veggies',
          emoji: '🥗',
          qty: 1,
          isSelected: true,
          isValidated: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _items.where((i) => i.isSelected).length;

    return Dialog(
      backgroundColor: const Color(0xFF0F1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with image preview
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    widget.imageFile,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Food Recognition',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confirm detected food items below',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),

            // Item list
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'No food items detected',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: item.isSelected
                                ? const Color(0xFF1E355E)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: item.isSelected
                                  ? const Color(0xFF4A90C4).withValues(alpha: 0.6)
                                  : Colors.white10,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              Checkbox(
                                value: item.isSelected,
                                activeColor: const Color(0xFF4A90C4),
                                onChanged: (val) {
                                  setState(() => item.isSelected = val ?? false);
                                },
                              ),
                              // Emoji
                              Text(
                                item.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 8),
                              // Editable Label
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) => item.label = val,
                                ),
                              ),
                              // Qty Stepper
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20),
                                    onPressed: item.qty > 1
                                        ? () => setState(() => item.qty--)
                                        : null,
                                  ),
                                  Text(
                                    '${item.qty}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
                                    onPressed: () => setState(() => item.qty++),
                                  ),
                                ],
                              ),
                              // Delete button
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setState(() => _items.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),
            // Add extra item button
            OutlinedButton.icon(
              onPressed: _addNewItem,
              icon: const Icon(Icons.add, color: Color(0xFF4A90C4)),
              label: const Text('Add Missing Item', style: TextStyle(color: Color(0xFF4A90C4))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4A90C4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Confirm & Save button
            ElevatedButton(
              onPressed: selectedCount == 0
                  ? null
                  : () {
                      final confirmed = _items.where((i) => i.isSelected).toList();
                      Navigator.pop(context, confirmed);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A4E7C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Save $selectedCount Item${selectedCount == 1 ? "" : "s"} to Virtual Fridge',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
