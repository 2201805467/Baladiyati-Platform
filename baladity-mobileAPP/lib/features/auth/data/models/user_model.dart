import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    super.avatar,
    super.role,
    super.departmentName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleJson = json['role'];
    final departmentJson = json['department'];

    return UserModel(
      id: json['id'] as int,
      name: json['full_name']?.toString() ?? json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatar: json['profile_image']?.toString() ?? json['avatar']?.toString(),
      role: roleJson is Map
          ? roleJson['role_name']?.toString()
          : json['role']?.toString(),
      departmentName: departmentJson is Map
          ? departmentJson['dept_name']?.toString() ??
                departmentJson['name']?.toString()
          : json['department_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': name,
    'email': email,
    if (phone != null) 'phone': phone,
    if (avatar != null) 'profile_image': avatar,
    if (role != null) 'role': role,
    if (departmentName != null) 'department_name': departmentName,
  };
}
