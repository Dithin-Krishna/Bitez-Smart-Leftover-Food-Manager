import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/barcode_service.dart';
import '../services/food_recognition_service.dart';
import '../services/fridge_service.dart';
import '../widgets/food_confirmation_dialog.dart';

/// Screen that scans food barcodes using the device camera,
/// looks up nutritional and expiration info on Open Food Facts,
/// and allows confirming or manually entering items into the fridge.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    await _lookupBarcode(rawValue.trim());
  }

  Future<void> _lookupBarcode(String barcode) async {
    // Query Open Food Facts
    final result = await BarcodeService.instance.fetchProductByBarcode(barcode);

    if (!mounted) return;

    if (result != null) {
      // Product found! Show confirmation dialog with parsed info
      final confirmedItems = await FoodConfirmationDialog.show(
        context,
        imageFile: null,
        title: 'Barcode: ${result.productName}',
        detectedItems: [result.foodItem],
      );

      if (!mounted) return;

      if (confirmedItems != null && confirmedItems.isNotEmpty) {
        await _saveItemsToFridge(confirmedItems);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // User cancelled confirmation, resume scanning
        setState(() => _isProcessing = false);
      }
    } else {
      // Product not found in Open Food Facts — prompt manual entry fallback
      await _showManualEntryFallback(barcode: barcode);
    }
  }

  Future<void> _showManualEntryFallback({String? barcode}) async {
    final nameCtrl = TextEditingController(text: barcode != null ? '' : '');
    int qty = 1;
    String selectedSection = 'pantry';
    DateTime expiryDate = DateTime.now().add(const Duration(days: 14));

    final sections = {
      'dairy': {'label': 'Dairy & Eggs', 'emoji': '🥛'},
      'veggies': {'label': 'Vegetables', 'emoji': '🥗'},
      'fruits': {'label': 'Fruits', 'emoji': '🍎'},
      'frozen': {'label': 'Frozen Foods', 'emoji': '🥟'},
      'drinks': {'label': 'Beverages', 'emoji': '🧃'},
      'condiments': {'label': 'Condiments', 'emoji': '🧂'},
      'pantry': {'label': 'Pantry', 'emoji': '🌾'},
    };

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16253D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Item Not Found',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    barcode != null
                        ? 'Barcode $barcode was not recognized in the database. Enter details manually to save it:'
                        : 'Enter food item details to save directly to your fridge:',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  // Food name input
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Food / Product Name',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'e.g. Greek Yogurt, Tomato Soup',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4A90C4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Section dropdown
                  const Text('Fridge Shelf', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSection,
                        dropdownColor: const Color(0xFF16253D),
                        isExpanded: true,
                        items: sections.entries.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: Row(
                              children: [
                                Text(e.value['emoji']!, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Text(e.value['label']!, style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => selectedSection = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantity stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quantity', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                            onPressed: qty > 1 ? () => setDlgState(() => qty--) : null,
                          ),
                          Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                            onPressed: () => setDlgState(() => qty++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Expiry date picker row (Feature 3 integration)
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expiryDate,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 730)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                              primary: const Color(0xFF2A4E7C),
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDlgState(() => expiryDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Color(0xFF4A90C4), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Expires: ${expiryDate.month}/${expiryDate.day}/${expiryDate.year}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const Icon(Icons.edit, color: Colors.white54, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A4E7C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final item = RecognizedFoodItem(
                    label: name,
                    category: sections[selectedSection]!['label']!,
                    section: selectedSection,
                    emoji: sections[selectedSection]!['emoji']!,
                    qty: qty,
                    isSelected: true,
                    isValidated: true,
                    expiresAt: expiryDate,
                  );

                  await _saveItemsToFridge([item]);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Add to Fridge'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveItemsToFridge(List<RecognizedFoodItem> items) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    for (final item in items) {
      try {
        await FridgeService.instance.addItem(
          token: token,
          emoji: item.emoji,
          label: item.label,
          qty: item.qty,
          color: _colorForSection(item.section),
          section: item.section,
          expiresAt: item.expiresAt,
        );
      } catch (e) {
        debugPrint('Failed to save barcode item: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Added ${items.length} item${items.length == 1 ? "" : "s"} to your fridge!'),
          backgroundColor: const Color(0xFF2A4E7C),
        ),
      );
    }
  }

  int _colorForSection(String section) {
    switch (section) {
      case 'dairy':
        return 0xFF1565C0;
      case 'veggies':
        return 0xFF2E7D32;
      case 'fruits':
        return 0xFFE65100;
      case 'frozen':
        return 0xFF0288D1;
      case 'drinks':
        return 0xFF00897B;
      default:
        return 0xFF2A4E7C;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Barcode',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Reticle viewfinder overlay
          Center(
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4A90C4), width: 2.5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90C4).withValues(alpha: 0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Center(
                child: Divider(color: Colors.redAccent, thickness: 1.5),
              ),
            ),
          ),

          // Top helper guidance
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Point camera at packaged food barcode',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // Processing spinner
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4A90C4)),
                    SizedBox(height: 16),
                    Text(
                      'Looking up product on Open Food Facts...',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Manual Entry fallback button
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              onPressed: () => _showManualEntryFallback(),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Can\'t scan? Enter item manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16253D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
