class UserEntity {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? role;
  final String? departmentName;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.role,
    this.departmentName,
  });

  /// Placeholder when a user object is needed but profile hasn't been fetched yet.
  const UserEntity.empty()
    : id = 0,
      name = '',
      email = '',
      phone = null,
      avatar = null,
      role = null,
      departmentName = null;

  bool get isDepartmentOfficer => role == 'department';
}
