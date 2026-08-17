enum ExpiryStatus { expired, expiringSoon, fresh, untracked }

/// Typical shelf-life (in days) for common fruits & veggies when refrigerated.
/// Used to auto-assign an expiry date when items are added to the fridge.
const Map<String, int> kFruitsVeggiesShelfLife = {
  // Veggies
  'tomato': 7, 'tomatoes': 7,
  'onion': 30, 'onions': 30,
  'garlic': 60, 'potato': 21, 'potatoes': 21,
  'carrot': 14, 'carrots': 14,
  'broccoli': 7, 'spinach': 5, 'lettuce': 7,
  'cabbage': 14, 'cucumber': 7, 'cucumbers': 7,
  'bell pepper': 10, 'capsicum': 10,
  'cauliflower': 7, 'zucchini': 7, 'corn': 3,
  'celery': 14, 'mushroom': 5, 'mushrooms': 5,
  'peas': 5, 'beans': 7, 'green beans': 7,
  'eggplant': 7, 'beet': 14, 'beets': 14,
  'radish': 7, 'ginger': 30, 'chili': 10,
  'coriander': 5, 'mint': 5, 'parsley': 7,
  'sweet potato': 21, 'yam': 14,
  // Fruits
  'apple': 30, 'apples': 30,
  'banana': 5, 'bananas': 5,
  'mango': 5, 'mangoes': 5,
  'orange': 14, 'oranges': 14,
  'grapes': 7, 'grape': 7,
  'strawberry': 3, 'strawberries': 3,
  'blueberry': 5, 'blueberries': 5,
  'watermelon': 7, 'pineapple': 5,
  'papaya': 5, 'guava': 5,
  'lemon': 21, 'lemons': 21, 'lime': 21,
  'kiwi': 7, 'peach': 5, 'pear': 7,
  'plum': 5, 'cherry': 5, 'cherries': 5,
  'coconut': 14, 'pomegranate': 14,
};

class FridgeItemModel {
  final String id;
  final String? userId;
  final String emoji;
  final String label;
  final int qty;
  final int color;
  final String section;
  final DateTime? expiresAt;
  final DateTime? manufacturingDate;
  final String? expiryImage;
  final String? expiryNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FridgeItemModel({
    required this.id,
    this.userId,
    required this.emoji,
    required this.label,
    required this.qty,
    required this.color,
    required this.section,
    this.expiresAt,
    this.manufacturingDate,
    this.expiryImage,
    this.expiryNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory FridgeItemModel.fromJson(Map<String, dynamic> json) {
    return FridgeItemModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'],
      emoji: json['emoji'] ?? '📦',
      label: json['label'] ?? 'Food Item',
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      color: (json['color'] as num?)?.toInt() ?? 0xFF2A4E7C,
      section: json['section'] ?? 'veggies',
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString())?.toLocal() : null,
      manufacturingDate: json['manufacturingDate'] != null ? DateTime.tryParse(json['manufacturingDate'].toString())?.toLocal() : null,
      expiryImage: json['expiryImage'],
      expiryNotes: json['expiryNotes'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString())?.toLocal() : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      if (userId != null) 'userId': userId,
      'emoji': emoji,
      'label': label,
      'qty': qty,
      'color': color,
      'section': section,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'manufacturingDate': manufacturingDate?.toUtc().toIso8601String(),
      'expiryImage': expiryImage,
      'expiryNotes': expiryNotes,
    };
  }

  /// Returns the default shelf-life in days for fruits/veggies based on label matching.
  int? get defaultShelfLifeDays {
    if (section != 'fruits' && section != 'veggies') return null;
    final key = label.trim().toLowerCase();
    if (kFruitsVeggiesShelfLife.containsKey(key)) return kFruitsVeggiesShelfLife[key];
    // Partial match (e.g. "Baby Spinach" → spinach)
    for (final entry in kFruitsVeggiesShelfLife.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) return entry.value;
    }
    // Generic fallback: fruits = 5 days, veggies = 7 days
    return section == 'fruits' ? 5 : 7;
  }

  /// Returns the effective expiry date:
  /// - If already set explicitly (scanned/manual), returns that.
  /// - If item is in fruits/veggies and has createdAt, computes from shelf life.
  DateTime? get effectiveExpiresAt {
    if (expiresAt != null) return expiresAt;
    final shelfDays = defaultShelfLifeDays;
    if (shelfDays != null && createdAt != null) {
      return createdAt!.add(Duration(days: shelfDays));
    }
    return null;
  }

  /// True when the expiry was auto-computed from shelf life, not manually set or scanned.
  bool get isAutoExpiry => expiresAt == null && effectiveExpiresAt != null;

  int? get daysRemaining {
    final exp = effectiveExpiresAt;
    if (exp == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = DateTime(exp.year, exp.month, exp.day);
    return expDate.difference(today).inDays;
  }

  ExpiryStatus get expiryStatus {
    final days = daysRemaining;
    if (days == null) return ExpiryStatus.untracked;
    if (days < 0) return ExpiryStatus.expired;
    if (days <= 3) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.fresh;
  }

  String get formattedExpiryDate {
    final exp = effectiveExpiresAt;
    if (exp == null) return 'No expiry set';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final tag = isAutoExpiry ? ' (est.)' : '';
    return '${exp.day} ${months[exp.month - 1]} ${exp.year}$tag';
  }

  String get formattedMfgDate {
    if (manufacturingDate == null) return 'Not set';
    final d = manufacturingDate!;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool get hasVaultPhoto => expiryImage != null && expiryImage!.trim().isNotEmpty;

  FridgeItemModel copyWith({
    String? id,
    String? userId,
    String? emoji,
    String? label,
    int? qty,
    int? color,
    String? section,
    DateTime? expiresAt,
    DateTime? manufacturingDate,
    String? expiryImage,
    String? expiryNotes,
  }) {
    return FridgeItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      label: label ?? this.label,
      qty: qty ?? this.qty,
      color: color ?? this.color,
      section: section ?? this.section,
      expiresAt: expiresAt ?? this.expiresAt,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      expiryImage: expiryImage ?? this.expiryImage,
      expiryNotes: expiryNotes ?? this.expiryNotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
