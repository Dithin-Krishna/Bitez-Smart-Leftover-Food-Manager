/// Dart representation of the user object returned by the API.
class UserModel {
  final String id;
  final String name;
  final String email;
  final int? age;
  final String? gender;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final List<String> dietaryRestrictions;
  final List<String> allergies;
  final int maxCookingTime; // In minutes, default 45

  bool get isAdmin => role == 'admin';

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.gender,
    this.phone,
    this.avatarUrl,
    this.role = 'user',
    this.dietaryRestrictions = const [],
    this.allergies = const [],
    this.maxCookingTime = 45,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:                  json['id']?.toString()    ?? json['_id']?.toString() ?? '',
      name:                json['name']?.toString()  ?? '',
      email:               json['email']?.toString() ?? '',
      age:                 json['age'] != null ? (json['age'] as num).toInt() : null,
      gender:              json['gender']?.toString(),
      phone:               json['phone']?.toString(),
      avatarUrl:           json['avatarUrl']?.toString(),
      role:                json['role']?.toString() ?? (json['isAdmin'] == true ? 'admin' : 'user'),
      dietaryRestrictions: json['dietaryRestrictions'] != null
          ? List<String>.from(json['dietaryRestrictions'].map((e) => e.toString()))
          : const [],
      allergies:           json['allergies'] != null
          ? List<String>.from(json['allergies'].map((e) => e.toString()))
          : const [],
      maxCookingTime:      json['maxCookingTime'] != null
          ? (json['maxCookingTime'] as num).toInt()
          : 45,
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    int? age,
    String? gender,
    String? phone,
    String? avatarUrl,
    String? role,
    List<String>? dietaryRestrictions,
    List<String>? allergies,
    int? maxCookingTime,
  }) {
    return UserModel(
      id:                  id ?? this.id,
      name:                name ?? this.name,
      email:               email ?? this.email,
      age:                 age ?? this.age,
      gender:              gender ?? this.gender,
      phone:               phone ?? this.phone,
      avatarUrl:           avatarUrl ?? this.avatarUrl,
      role:                role ?? this.role,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      allergies:           allergies ?? this.allergies,
      maxCookingTime:      maxCookingTime ?? this.maxCookingTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':                  id,
      'name':                name,
      'email':               email,
      'age':                 age,
      'gender':              gender,
      'phone':               phone,
      'avatarUrl':           avatarUrl,
      'role':                role,
      'dietaryRestrictions': dietaryRestrictions,
      'allergies':           allergies,
      'maxCookingTime':      maxCookingTime,
    };
  }
}
