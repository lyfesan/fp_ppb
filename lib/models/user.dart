class User{
  final String id;
  final String name;
  final String email;
  final String password;
  final String? photo;
  final String? typeAccount;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final String? role; 

  // Constructor
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.photo,
    this.typeAccount,
    this.createdAt,
    required this.updatedAt,
    this.role,
  });
}