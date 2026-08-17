import 'api_service.dart';

/// Data class representing a Grocery Item
class GroceryItemData {
  final String id;
  final String label;
  final String emoji;
  final int qty;
  final String category;
  final String section;
  final bool isBought;
  final bool isAiSuggested;
  final String? reason;

  GroceryItemData({
    required this.id,
    required this.label,
    this.emoji = '🛒',
    this.qty = 1,
    this.category = 'Produce',
    this.section = 'veggies',
    this.isBought = false,
    this.isAiSuggested = false,
    this.reason,
  });

  factory GroceryItemData.fromJson(Map<String, dynamic> json) {
    return GroceryItemData(
      id: json['_id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Item',
      emoji: json['emoji']?.toString() ?? '🛒',
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      category: json['category']?.toString() ?? 'Produce',
      section: json['section']?.toString() ?? 'veggies',
      isBought: json['isBought'] == true,
      isAiSuggested: json['isAiSuggested'] == true,
      reason: json['reason']?.toString(),
    );
  }
}

/// Service managing API communication for the Smart Grocery List
class GroceryService {
  GroceryService._();
  static final GroceryService instance = GroceryService._();

  /// Fetch all grocery items for user
  Future<List<GroceryItemData>> getGroceryList({required String token}) async {
    final response = await ApiService.instance.get('/api/grocery', token: token);
    final items = response['items'] as List<dynamic>? ?? [];
    return items.map((i) => GroceryItemData.fromJson(i as Map<String, dynamic>)).toList();
  }

  /// Add custom grocery item
  Future<GroceryItemData> addItem({
    required String token,
    required String label,
    String? emoji,
    int qty = 1,
    String? category,
    String? section,
  }) async {
    final response = await ApiService.instance.post(
      '/api/grocery',
      {
        'label': label,
        if (emoji != null) 'emoji': emoji,
        'qty': qty,
        if (category != null) 'category': category,
        if (section != null) 'section': section,
      },
      token: token,
    );
    return GroceryItemData.fromJson(response['item'] as Map<String, dynamic>);
  }

  /// Generate AI Smart Restock suggestions based on current Virtual Fridge
  Future<List<GroceryItemData>> generateAiSuggestions({required String token}) async {
    final response = await ApiService.instance.post(
      '/api/grocery/generate',
      {},
      token: token,
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items.map((i) => GroceryItemData.fromJson(i as Map<String, dynamic>)).toList();
  }

  /// Toggle item bought status or update quantity
  Future<GroceryItemData> updateItem({
    required String token,
    required String id,
    bool? isBought,
    int? qty,
  }) async {
    final response = await ApiService.instance.put(
      '/api/grocery/$id',
      {
        if (isBought != null) 'isBought': isBought,
        if (qty != null) 'qty': qty,
      },
      token: token,
    );
    return GroceryItemData.fromJson(response['item'] as Map<String, dynamic>);
  }

  /// Delete a grocery item
  Future<void> deleteItem({required String token, required String id}) async {
    await ApiService.instance.delete('/api/grocery/$id', token: token);
  }

  /// Transfer all bought grocery items directly into Virtual Fridge
  Future<int> moveBoughtToFridge({required String token}) async {
    final response = await ApiService.instance.post('/api/grocery/move-to-fridge', {}, token: token);
    return (response['movedCount'] as num?)?.toInt() ?? 0;
  }
}
