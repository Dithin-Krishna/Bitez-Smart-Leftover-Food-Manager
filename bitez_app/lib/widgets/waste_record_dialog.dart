import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/fridge_service.dart';
import '../services/waste_service.dart';

/// Modal dialog presented when a user removes an item from the fridge or expiry vault.
/// Allows recording whether the food was consumed or discarded as waste (with reason).
class WasteRecordDialog extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String category;
  final int currentQty;
  final String unit;

  const WasteRecordDialog({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.currentQty,
    this.unit = 'item',
  });

  /// Shows the dialog and returns true if the item was processed/removed
  static Future<bool?> show(
    BuildContext context, {
    required String itemId,
    required String itemName,
    required String category,
    required int currentQty,
    String unit = 'item',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => WasteRecordDialog(
        itemId: itemId,
        itemName: itemName,
        category: category,
        currentQty: currentQty,
        unit: unit,
      ),
    );
  }

  @override
  State<WasteRecordDialog> createState() => _WasteRecordDialogState();
}

class _WasteRecordDialogState extends State<WasteRecordDialog> {
  bool _isWaste = false;
  late int _quantity;
  String _selectedReason = 'Expired';
  bool _loading = false;

  final List<Map<String, dynamic>> _reasons = [
    {'title': 'Expired', 'icon': Icons.hourglass_bottom_rounded, 'desc': 'Passed expiration date'},
    {'title': 'Spoiled', 'icon': Icons.coronavirus_outlined, 'desc': 'Moldy, smelled or tasted bad'},
    {'title': 'Excess quantity', 'icon': Icons.inventory_2_outlined, 'desc': 'Bought or made too much'},
    {'title': 'Forgotten food', 'icon': Icons.visibility_off_outlined, 'desc': 'Lost in back of fridge'},
    {'title': 'Preparation error', 'icon': Icons.soup_kitchen_outlined, 'desc': 'Burned or ruined during cooking'},
    {'title': 'Other', 'icon': Icons.more_horiz_rounded, 'desc': 'Miscellaneous discard reason'},
  ];

  @override
  void initState() {
    super.initState();
    _quantity = widget.currentQty > 0 ? widget.currentQty : 1;
  }

  Future<void> _handleConfirm() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _loading = true);

    try {
      if (_isWaste) {
        // Record waste event
        await WasteService.instance.recordWaste(
          token: token,
          foodItemId: widget.itemId,
          foodName: widget.itemName,
          category: widget.category,
          quantity: _quantity.toDouble(),
          unit: widget.unit,
          reason: _selectedReason,
        );

        // Also notify fridge update
        FridgeService.instance.notifyFridgeChanged();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Waste recorded: ${widget.itemName} ($_selectedReason)'),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      } else {
        // Consumed normally — just remove from fridge
        await FridgeService.instance.deleteItem(token: token, id: widget.itemId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('😋 ${widget.itemName} consumed!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isWaste ? Colors.redAccent.withValues(alpha: 0.2) : Colors.greenAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isWaste ? Icons.delete_outline_rounded : Icons.restaurant_rounded,
                      color: _isWaste ? Colors.redAccent : const Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Category: ${widget.category}',
                          style: const TextStyle(fontSize: 13, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mode selector: Consumed vs Wasted
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isWaste = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isWaste ? const Color(0xFF10B981) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 16,
                                  color: !_isWaste ? Colors.white : Colors.white60),
                              const SizedBox(width: 6),
                              Text(
                                'Consumed',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: !_isWaste ? Colors.white : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isWaste = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isWaste ? const Color(0xFFDC2626) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 16,
                                  color: _isWaste ? Colors.white : Colors.white60),
                              const SizedBox(width: 6),
                              Text(
                                'Wasted / Discard',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _isWaste ? Colors.white : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // If marked as waste, show reason selection
              if (_isWaste) ...[
                const Text(
                  'Reason for discarding:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _reasons.map((r) {
                    final isSelected = _selectedReason == r['title'];
                    return ChoiceChip(
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedReason = r['title'] as String);
                        }
                      },
                      avatar: Icon(r['icon'] as IconData, size: 14,
                          color: isSelected ? Colors.white : Colors.white70),
                      label: Text(r['title'] as String),
                      selectedColor: const Color(0xFFDC2626),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Quantity selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quantity discarded:',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white60),
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        ),
                        Text(
                          '$_quantity ${widget.unit}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white60),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Great job enjoying your food! Removing this item will clear it from your active inventory without recording waste.',
                  style: TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
                ),
              ],
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isWaste ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isWaste ? 'Record Waste' : 'Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
