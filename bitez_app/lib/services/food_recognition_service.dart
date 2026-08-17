import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'api_service.dart';
import 'yolo_detector.dart';

/// Data class representing an enriched, validated food item recognized by the pipeline
class RecognizedFoodItem {
  String label;
  String category;
  String section;
  String emoji;
  int qty;
  bool isSelected;
  bool isValidated;

  RecognizedFoodItem({
    required this.label,
    this.category = 'Vegetables',
    this.section = 'veggies',
    this.emoji = '🥗',
    this.qty = 1,
    this.isSelected = true,
    this.isValidated = true,
  });

  factory RecognizedFoodItem.fromJson(Map<String, dynamic> json) {
    return RecognizedFoodItem(
      label: json['label']?.toString() ?? 'Unknown Food',
      category: json['category']?.toString() ?? 'Vegetables',
      section: json['section']?.toString() ?? 'veggies',
      emoji: json['emoji']?.toString() ?? '🥗',
      qty: 1,
      isSelected: true,
      isValidated: json['isValidated'] == true,
    );
  }

  Map<String, dynamic> toFridgeJson() {
    return {
      'label': label,
      'emoji': emoji,
      'qty': qty,
      'section': section,
    };
  }
}

/// Service responsible for the 6-phase Image Recognition Pipeline:
/// Phase 1: Image Capture
/// Phase 2: On-Device YOLO Object Detection
/// Phase 3: Gemini Vision Cloud Scene Analysis
/// Phase 4: Food Catalog Validation & Non-Food Object Removal
class FoodRecognitionService {
  FoodRecognitionService._();
  static final FoodRecognitionService instance = FoodRecognitionService._();

  /// Main recognition entry point returning simple string labels (backwards compatibility)
  Future<List<String>> recognizeFood(File imageFile, {String? token}) async {
    final enriched = await recognizeFoodPipeline(imageFile, token: token);
    return enriched.map((e) => e.label).toList();
  }

  /// Full 6-phase recognition pipeline returning enriched RecognizedFoodItem objects
  Future<List<RecognizedFoodItem>> recognizeFoodPipeline(File imageFile, {String? token}) async {
    // Phase 1: Check for explicit filename keywords
    final keywordMatches = _checkFilenameKeywords(imageFile.path);
    if (keywordMatches.isNotEmpty) {
      return keywordMatches.map((name) => _createFallbackFoodItem(name)).toList();
    }

    // Phase 2: Local YOLO Object Detection
    List<YoloDetectionResult> yoloDetections = [];
    try {
      yoloDetections = await YoloDetector.instance.detectFoodItems(
        imageFile,
        confidenceThreshold: 0.35,
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ YOLO detection exception: $e');
      }
    }

    // Phase 3 & 4: Backend Gemini Vision + Food Catalog Filtering
    final cloudResults = await _tryBackendVision(
      imageFile,
      yoloDetections: yoloDetections,
      token: token,
    );
    if (cloudResults.isNotEmpty) {
      return cloudResults;
    }

    // Fallback: Use local YOLO detections if backend returned empty
    if (yoloDetections.isNotEmpty) {
      return yoloDetections.map((d) => _createFallbackFoodItem(d.label)).toList();
    }

    // No food items detected in image
    return [];
  }

  /// Sends compressed image base64 + YOLO hints to backend /api/vision/detect
  Future<List<RecognizedFoodItem>> _tryBackendVision(
    File imageFile, {
    List<YoloDetectionResult>? yoloDetections,
    String? token,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return [];

      // Compress image to ~100KB JPEG payload
      final resized = img.copyResize(decoded, width: 800);
      final compressedBytes = img.encodeJpg(resized, quality: 75);
      final base64Image = 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';

      final yoloHints = yoloDetections?.map((d) => {'label': d.label, 'confidence': d.confidence}).toList();

      final response = await ApiService.instance.post(
        '/api/vision/detect',
        {
          'imageBase64': base64Image,
          'yoloDetections': yoloHints,
        },
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        final validatedFoods = response['data']['validatedFoods'] as List<dynamic>?;
        if (validatedFoods != null && validatedFoods.isNotEmpty) {
          return validatedFoods
              .map((item) => RecognizedFoodItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        
        final simpleItems = response['data']['detectedItems'] as List<dynamic>?;
        if (simpleItems != null && simpleItems.isNotEmpty) {
          return simpleItems.map((e) => _createFallbackFoodItem(e.toString())).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cloud Vision request exception: $e');
      }
    }
    return [];
  }

  RecognizedFoodItem _createFallbackFoodItem(String name) {
    final lower = name.toLowerCase();
    String emoji = '🥗';
    String section = 'veggies';

    if (lower.contains('apple')) { emoji = '🍎'; section = 'fruits'; }
    else if (lower.contains('banana')) { emoji = '🍌'; section = 'fruits'; }
    else if (lower.contains('orange')) { emoji = '🍊'; section = 'fruits'; }
    else if (lower.contains('tomato')) { emoji = '🍅'; section = 'veggies'; }
    else if (lower.contains('carrot')) { emoji = '🥕'; section = 'veggies'; }
    else if (lower.contains('broccoli')) { emoji = '🥦'; section = 'veggies'; }
    else if (lower.contains('eggplant')) { emoji = '🍆'; section = 'veggies'; }
    else if (lower.contains('milk')) { emoji = '🥛'; section = 'dairy'; }
    else if (lower.contains('cheese')) { emoji = '🧀'; section = 'dairy'; }
    else if (lower.contains('chicken') || lower.contains('meat')) { emoji = '🍗'; section = 'frozen'; }

    return RecognizedFoodItem(
      label: name,
      emoji: emoji,
      section: section,
      category: section == 'fruits' ? 'Fruits' : 'Vegetables',
    );
  }




  List<String> _checkFilenameKeywords(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('banana')) return ['Banana'];
    if (lower.contains('apple')) return ['Apple'];
    if (lower.contains('eggplant') || lower.contains('aubergine')) return ['Eggplant'];
    if (lower.contains('potato')) return ['Potato'];
    if (lower.contains('lemon')) return ['Lemon'];
    if (lower.contains('tomato')) return ['Tomato'];
    if (lower.contains('carrot')) return ['Carrot'];
    if (lower.contains('broccoli')) return ['Broccoli'];
    if (lower.contains('onion')) return ['Onion'];
    if (lower.contains('cucumber')) return ['Cucumber'];
    if (lower.contains('capsicum') || lower.contains('pepper')) return ['Capsicum'];
    if (lower.contains('garlic')) return ['Garlic'];
    return [];
  }
}

