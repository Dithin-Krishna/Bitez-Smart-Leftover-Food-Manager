import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/fridge_item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/expiry_provider.dart';
import '../services/expiry_service.dart';
import '../services/fridge_service.dart';
import '../services/local_photo_storage.dart';

class ExpiryScanDialog extends StatefulWidget {
  final FridgeItemModel? item;

  const ExpiryScanDialog({super.key, this.item});

  static Future<void> show(BuildContext context, {FridgeItemModel? item}) {
    return showDialog(
      context: context,
      builder: (_) => ExpiryScanDialog(item: item),
    );
  }

  @override
  State<ExpiryScanDialog> createState() => _ExpiryScanDialogState();
}

class _ExpiryScanDialogState extends State<ExpiryScanDialog> {
  File? _pickedFile;
  bool _isScanning = false;
  DateTime? _selectedExpiryDate;
  DateTime? _selectedMfgDate;
  final _notesController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _selectedExpiryDate = widget.item!.expiresAt;
      _selectedMfgDate = widget.item!.manufacturingDate;
      _notesController.text = widget.item!.expiryNotes ?? '';
      _labelController.text = widget.item!.label;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScanImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, imageQuality: 85);
      if (xfile == null) return;

      final file = File(xfile.path);
      setState(() {
        _pickedFile = file;
        _isScanning = true;
      });

      // ignore: use_build_context_synchronously
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        final result = await ExpiryService.instance.scanExpiryPhoto(
          token: token,
          imageFile: file,
        );

        if (mounted) {
          setState(() {
            _isScanning = false;
            if (result.expiryDate != null) _selectedExpiryDate = result.expiryDate;
            if (result.manufacturingDate != null) _selectedMfgDate = result.manufacturingDate;
            if (result.itemLabel != null && result.itemLabel!.isNotEmpty && _labelController.text.isEmpty) {
              _labelController.text = result.itemLabel!;
            }
            if (result.notes.isNotEmpty && _notesController.text.isEmpty) {
              _notesController.text = result.notes;
            }
          });

          // ── Auto-save immediately if an expiry date was found and we have a target item ──
          if (result.expiryDate != null && widget.item != null) {
            await _autoSaveOcrResult(token, file, result);
          } else if (result.expiryDate != null) {
            // Show confirmation banner for new item (no item context)
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ AI found expiry: ${result.expiryDate!.day}/${result.expiryDate!.month}/${result.expiryDate!.year}. Tap "Save" to confirm.',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ No expiry date found in photo. Please enter manually.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning photo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Auto-saves OCR result to vault immediately without user tapping Save.
  /// Saves the photo locally and sends just the file path to MongoDB.
  Future<void> _autoSaveOcrResult(String token, File imageFile, ExpiryOcrResult result) async {
    if (widget.item == null) return;
    try {
      // Save photo to device storage, get local path
      final localPath = await LocalPhotoStorage.instance.saveExpiryPhoto(
        imageFile,
        itemId: widget.item!.id,
      );

      // ignore: use_build_context_synchronously
      final provider = context.read<ExpiryProvider>();
      await provider.updateItemExpiry(
        token: token,
        itemId: widget.item!.id,
        expiresAt: result.expiryDate,
        manufacturingDate: result.manufacturingDate ?? _selectedMfgDate,
        expiryImage: localPath,   // ← just the path, not Base64
        expiryNotes: result.notes.isNotEmpty ? result.notes : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Expiry date auto-detected & saved! Expires: ${result.expiryDate!.day}/${result.expiryDate!.month}/${result.expiryDate!.year}',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-save failed: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }



  Future<void> _pickDate(bool isExpiry) async {
    final initial = isExpiry
        ? (_selectedExpiryDate ?? DateTime.now().add(const Duration(days: 7)))
        : (_selectedMfgDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isExpiry) {
          _selectedExpiryDate = picked;
        } else {
          _selectedMfgDate = picked;
        }
      });
    }
  }

  Future<void> _saveToVault() async {
    if (widget.item == null && _labelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final provider = context.read<ExpiryProvider>();

    // Save photo locally and get path; keep existing path if no new photo
    String? imagePath;
    if (_pickedFile != null) {
      final itemId = widget.item?.id;
      // Delete old local photo if replacing
      if (widget.item?.expiryImage != null &&
          LocalPhotoStorage.isLocalPath(widget.item!.expiryImage)) {
        await LocalPhotoStorage.instance.deletePhoto(widget.item!.expiryImage);
      }
      imagePath = await LocalPhotoStorage.instance.saveExpiryPhoto(
        _pickedFile!,
        itemId: itemId,
      );
    } else {
      imagePath = widget.item?.expiryImage; // keep existing
    }

    if (widget.item != null) {
      await provider.updateItemExpiry(
        token: token,
        itemId: widget.item!.id,
        expiresAt: _selectedExpiryDate,
        manufacturingDate: _selectedMfgDate,
        expiryImage: imagePath,
        expiryNotes: _notesController.text.trim(),
      );
    } else {
      final label = _labelController.text.trim();
      final created = await FridgeService.instance.addItem(
        token: token,
        emoji: '📦',
        label: label,
        qty: 1,
        color: 0xFF2A4E7C,
        section: 'veggies',
      );
      final newItemId = created['_id'] ?? created['id'];
      if (newItemId != null) {
        await provider.updateItemExpiry(
          token: token,
          itemId: newItemId.toString(),
          expiresAt: _selectedExpiryDate,
          manufacturingDate: _selectedMfgDate,
          expiryImage: imagePath,
          expiryNotes: _notesController.text.trim(),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Expiry record & Vault photo saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.cardColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2A4E7C),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.document_scanner, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item != null ? 'Scan Expiry for ${widget.item!.label}' : 'Scan Expiry Label',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Image Picker Area
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.camera_alt),
                            title: const Text('Take Photo with Camera'),
                            onTap: () {
                              Navigator.pop(context);
                              _pickAndScanImage(ImageSource.camera);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text('Choose from Gallery'),
                            onTap: () {
                              Navigator.pop(context);
                              _pickAndScanImage(ImageSource.gallery);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primary.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: _isScanning
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('🔍 AI Reading Expiry Label...', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      : _pickedFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Image.file(_pickedFile!, width: double.infinity, height: 180, fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text('Tap to change', style: TextStyle(color: Colors.white, fontSize: 11)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, size: 40, color: primary),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to take photo of expiry date label',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: primary, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text('Gemini AI will automatically detect dates', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                              ],
                            ),
                ),
              ),

              const SizedBox(height: 16),

              if (widget.item == null) ...[
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    prefixIcon: Icon(Icons.label_outlined),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Expiry Date Field
              InkWell(
                onTap: () => _pickDate(true),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expiration Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              _selectedExpiryDate != null
                                  ? '${_selectedExpiryDate!.day}/${_selectedExpiryDate!.month}/${_selectedExpiryDate!.year}'
                                  : 'Not set (Tap to pick date)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Mfg Date Field
              InkWell(
                onTap: () => _pickDate(false),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.precision_manufacturing_outlined, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Manufacturing Date (Optional)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              _selectedMfgDate != null
                                  ? '${_selectedMfgDate!.day}/${_selectedMfgDate!.month}/${_selectedMfgDate!.year}'
                                  : 'Not set (Tap to pick date)',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Expiry Notes / Batch Info',
                  hintText: 'e.g., Best before 14 days after opening',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _saveToVault,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save to Expiry Vault'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A4E7C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
