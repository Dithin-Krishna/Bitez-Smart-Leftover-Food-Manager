import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/fridge_item_model.dart';
import 'api_service.dart';

class ExpiryOcrResult {
  final DateTime? expiryDate;
  final DateTime? manufacturingDate;
  final String? itemLabel;
  final String rawText;
  final String notes;

  ExpiryOcrResult({
    this.expiryDate,
    this.manufacturingDate,
    this.itemLabel,
    required this.rawText,
    required this.notes,
  });

  factory ExpiryOcrResult.fromJson(Map<String, dynamic> json) {
    return ExpiryOcrResult(
      expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate'].toString()) : null,
      manufacturingDate: json['manufacturingDate'] != null ? DateTime.tryParse(json['manufacturingDate'].toString()) : null,
      itemLabel: json['itemLabel'],
      rawText: json['rawText'] ?? '',
      notes: json['notes'] ?? '',
    );
  }
}

class ExpirySummaryData {
  final int totalTracked;
  final int expiredCount;
  final int expiringSoonCount;
  final int freshCount;
  final List<FridgeItemModel> items;

  ExpirySummaryData({
    required this.totalTracked,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.freshCount,
    required this.items,
  });
}

class ExpiryService {
  ExpiryService._();
  static final ExpiryService instance = ExpiryService._();

  /// Fetches items with expiry dates and summary statistics
  Future<ExpirySummaryData> fetchExpirySummary({required String token}) async {
    try {
      final res = await ApiService.instance.get('/api/fridge/expiry-summary', token: token);
      final summaryJson = res['summary'] as Map<String, dynamic>? ?? {};
      final itemsJson = res['items'] as List<dynamic>? ?? [];

      final items = itemsJson.map((i) => FridgeItemModel.fromJson(i as Map<String, dynamic>)).toList();

      return ExpirySummaryData(
        totalTracked: (summaryJson['totalTracked'] as num?)?.toInt() ?? items.length,
        expiredCount: (summaryJson['expiredCount'] as num?)?.toInt() ?? 0,
        expiringSoonCount: (summaryJson['expiringSoonCount'] as num?)?.toInt() ?? 0,
        freshCount: (summaryJson['freshCount'] as num?)?.toInt() ?? 0,
        items: items,
      );
    } catch (e) {
      debugPrint('Error fetching expiry summary: $e');
      rethrow;
    }
  }

  /// Updates expiry date, mfg date, vault photo, and notes for a fridge item
  Future<FridgeItemModel> updateItemExpiry({
    required String token,
    required String itemId,
    DateTime? expiresAt,
    DateTime? manufacturingDate,
    String? expiryImage,
    String? expiryNotes,
  }) async {
    final payload = <String, dynamic>{};
    if (expiresAt != null) payload['expiresAt'] = expiresAt.toUtc().toIso8601String();
    if (manufacturingDate != null) payload['manufacturingDate'] = manufacturingDate.toUtc().toIso8601String();
    if (expiryImage != null) payload['expiryImage'] = expiryImage;
    if (expiryNotes != null) payload['expiryNotes'] = expiryNotes;

    final res = await ApiService.instance.put('/api/fridge/$itemId', payload, token: token);
    final itemJson = res['item'] as Map<String, dynamic>;
    return FridgeItemModel.fromJson(itemJson);
  }

  /// Sends packaging/label photo to Gemini Vision API for expiry date OCR recognition
  Future<ExpiryOcrResult> scanExpiryPhoto({
    required String token,
    required File imageFile,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    final res = await ApiService.instance.post(
      '/api/vision/expiry-ocr',
      {'imageBase64': base64Image},
      token: token,
    );

    final ocrJson = res['ocrResult'] as Map<String, dynamic>? ?? {};
    return ExpiryOcrResult.fromJson(ocrJson);
  }
}
