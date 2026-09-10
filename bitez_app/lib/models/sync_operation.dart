import 'dart:convert';

/// Types of mutations that can be performed while offline.
enum SyncOpType {
  addFridgeItem,
  updateFridgeQty,
  deleteFridgeItem,
  deductFridgeItems,
  addGroceryItem,
  updateGroceryItem,
  deleteGroceryItem,
  bulkGroceryItems,
}

/// Represents a queued write mutation to be synced when internet returns.
class SyncOperation {
  final String id;
  final SyncOpType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      type: SyncOpType.values.byName(json['type'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory SyncOperation.deserialize(String raw) =>
      SyncOperation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
