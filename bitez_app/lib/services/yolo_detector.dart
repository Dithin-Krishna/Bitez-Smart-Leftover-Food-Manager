import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Detector result holding label name, confidence score, and optional bounding box
class YoloDetectionResult {
  final String label;
  final double confidence;
  final List<double>? boundingBox; // [x, y, w, h] normalized 0.0 - 1.0

  const YoloDetectionResult({
    required this.label,
    required this.confidence,
    this.boundingBox,
  });

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(1)}%)';
}

/// YOLO & Neural Network Object Detector service for food items.
class YoloDetector {
  YoloDetector._();
  static final YoloDetector instance = YoloDetector._();

  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Lazy-loads local TFLite neural model and label list
  Future<bool> initModel() async {
    if (_isLoaded) return true;
    try {
      // Load model interpreter
      _interpreter = await Interpreter.fromAsset('assets/models/vegetable_model.tflite');
      
      // Load labels file
      final labelsStr = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsStr
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      _isLoaded = _interpreter != null && _labels != null && _labels!.isNotEmpty;
      return _isLoaded;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ YoloDetector init model error: $e');
      }
      _isLoaded = false;
      return false;
    }
  }

  /// Detects food items from an image file
  Future<List<YoloDetectionResult>> detectFoodItems(
    File imageFile, {
    double confidenceThreshold = 0.35,
  }) async {
    final ready = await initModel();
    if (!ready || _interpreter == null || _labels == null) {
      return [];
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return [];

      // 1. Resize image to model resolution (224x224)
      final resized = img.copyResize(decoded, width: 224, height: 224);

      // 2. Build normalized Float32 RGB tensor input: [1, 224, 224, 3]
      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      final numClasses = _labels!.length;
      final output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);

      // 3. Run Inference
      _interpreter!.run(input, output);

      // 4. Parse raw output values
      final rawOutputs = (output[0] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
      if (rawOutputs.isEmpty) return [];

      // Check if output is already softmaxed probabilities (sum ~ 1.0)
      final sumRaw = rawOutputs.reduce((a, b) => a + b);
      List<double> probabilities;
      
      if (sumRaw > 0.8 && sumRaw < 1.2) {
        probabilities = rawOutputs;
      } else {
        final double maxLogit = rawOutputs.reduce((a, b) => math.max(a, b));
        final expValues = rawOutputs.map((v) => math.exp(v - maxLogit)).toList();
        final double sumExp = expValues.reduce((a, b) => a + b);
        probabilities = sumExp > 0
            ? expValues.map((v) => v / sumExp).toList()
            : rawOutputs;
      }

      final results = <YoloDetectionResult>[];
      final effectiveThreshold = math.min(confidenceThreshold, 0.15);

      for (int i = 0; i < probabilities.length && i < _labels!.length; i++) {
        final score = probabilities[i];
        if (score >= effectiveThreshold) {
          results.add(
            YoloDetectionResult(
              label: _labels![i],
              confidence: score,
            ),
          );
        }
      }

      // Sort by confidence descending
      results.sort((a, b) => b.confidence.compareTo(a.confidence));
      return results;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error during YOLO detection: $e');
      }
      return [];
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
