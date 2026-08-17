import 'api_service.dart';

/// CRUD operations for the fridge via the Bitez backend.
class FridgeService {
  FridgeService._();
  static final FridgeService instance = FridgeService._();

  // ── GET /api/fridge ────────────────────────────────────────────────────────
  /// Returns items grouped by section key.
  /// Each item map contains all backend fields, including '_id'.
  Future<Map<String, List<Map<String, dynamic>>>> getGrouped(String token) async {
    final json = await ApiService.instance.get('/api/fridge', token: token);
    final raw  = json['grouped'] as Map<String, dynamic>;
    return raw.map((section, list) {
      final items = (list as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return MapEntry(section, items);
    });
  }

  /// Returns flat list of all fridge items for the user.
  Future<List<Map<String, dynamic>>> getAllItems({required String token}) async {
    final json = await ApiService.instance.get('/api/fridge', token: token);
    final rawList = json['items'] as List<dynamic>? ?? [];
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── POST /api/fridge ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addItem({
    required String token,
    required String emoji,
    required String label,
    required int qty,
    required int color,
    required String section,
  }) async {
    final json = await ApiService.instance.post(
      '/api/fridge',
      {
        'emoji':   emoji,
        'label':   label,
        'qty':     qty,
        'color':   color,
        'section': section,
      },
      token: token,
    );
    return Map<String, dynamic>.from(json['item'] as Map);
  }

  // ── PATCH /api/fridge/:id/qty ──────────────────────────────────────────────
  Future<Map<String, dynamic>> updateQty({
    required String token,
    required String id,
    required int delta,
  }) async {
    final json = await ApiService.instance.patch(
      '/api/fridge/$id/qty',
      {'delta': delta},
      token: token,
    );
    return Map<String, dynamic>.from(json['item'] as Map);
  }

  // ── POST /api/fridge/bulk ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> addBulkItems({
    required String token,
    required List<Map<String, dynamic>> items,
  }) async {
    final json = await ApiService.instance.post(
      '/api/fridge/bulk',
      {'items': items},
      token: token,
    );
    final rawList = json['items'] as List<dynamic>? ?? [];
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── DELETE /api/fridge/:id ─────────────────────────────────────────────────
  Future<void> deleteItem({required String token, required String id}) async {
    await ApiService.instance.delete('/api/fridge/$id', token: token);
  }
}

