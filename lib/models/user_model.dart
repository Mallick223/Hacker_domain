class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? emergencyContact;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.emergencyContact,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      emergencyContact: json['emergency_contact'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'emergency_contact': emergencyContact,
      };
}
