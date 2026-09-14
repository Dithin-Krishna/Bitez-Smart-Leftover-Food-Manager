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
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:        json['id']?.toString()    ?? '',
      name:      json['name']?.toString()  ?? '',
      email:     json['email']?.toString() ?? '',
      age:       json['age'] != null ? (json['age'] as num).toInt() : null,
      gender:    json['gender']?.toString(),
      phone:     json['phone']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      role:      json['role']?.toString() ?? (json['isAdmin'] == true ? 'admin' : 'user'),
    );
  }
}
