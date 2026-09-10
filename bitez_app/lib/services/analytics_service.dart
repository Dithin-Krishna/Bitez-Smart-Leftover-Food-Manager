import '../models/analytics_model.dart';
import 'api_service.dart';

/// Service responsible for fetching waste reduction and financial savings analytics.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// GET /api/analytics/waste-savings
  Future<WasteSavingsAnalytics> getWasteSavingsAnalytics(String token) async {
    try {
      final json = await ApiService.instance.get(
        '/api/analytics/waste-savings',
        token: token,
      );
      return WasteSavingsAnalytics.fromJson(json);
    } catch (_) {
      rethrow;
    }
  }
}
