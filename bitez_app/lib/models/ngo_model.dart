// Dart model representing Community Food Banks, Shelters, and NGOs
// Mapped to Sections 12.8 & 22 in the MCA Mini Project Report.

class NgoModel {
  final String id;
  final String name;
  final String type;
  final String description;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String operatingHours;
  final List<String> acceptedItems;
  final bool isVerified;
  final double distanceKm;

  const NgoModel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
    required this.operatingHours,
    required this.acceptedItems,
    this.isVerified = true,
    required this.distanceKm,
  });

  factory NgoModel.fromJson(Map<String, dynamic> json) {
    final rawAccepted = json['acceptedItems'] as List<dynamic>? ?? [];
    return NgoModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? 'Community Food Bank',
      type: json['type']?.toString() ?? 'Food Bank',
      description: json['description']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? 'Kochi',
      operatingHours: json['operatingHours']?.toString() ?? '9:00 AM - 6:00 PM',
      acceptedItems: rawAccepted.map((e) => e.toString()).toList(),
      isVerified: json['isVerified'] != false,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 2.5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'operatingHours': operatingHours,
      'acceptedItems': acceptedItems,
      'isVerified': isVerified,
      'distanceKm': distanceKm,
    };
  }
}
