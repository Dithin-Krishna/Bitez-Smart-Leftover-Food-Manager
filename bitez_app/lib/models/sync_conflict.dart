import 'dart:convert';

/// Represents a synchronization conflict where server state prevailed over offline edits.
class SyncConflict {
  final String id;
  final String entityType; // 'fridge' | 'grocery'
  final String entityId;
  final String itemLabel;
  final String message;
  final DateTime timestamp;
  bool isDismissed;

  SyncConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.itemLabel,
    required this.message,
    DateTime? timestamp,
    this.isDismissed = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'itemLabel': itemLabel,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'isDismissed': isDismissed,
      };

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      id: json['id'] as String,
      entityType: json['entityType']?.toString() ?? 'fridge',
      entityId: json['entityId']?.toString() ?? '',
      itemLabel: json['itemLabel']?.toString() ?? 'Item',
      message: json['message']?.toString() ?? 'Conflict occurred',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isDismissed: json['isDismissed'] == true,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory SyncConflict.deserialize(String raw) =>
      SyncConflict.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
