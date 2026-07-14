/// Dart representation of the user object returned by the API.
class UserModel {
  final String id;
  final String name;
  final String email;
  final int? age;
  final String? gender;
  final String? phone;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.gender,
    this.phone,
    this.avatarUrl,
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
    );
  }
}
