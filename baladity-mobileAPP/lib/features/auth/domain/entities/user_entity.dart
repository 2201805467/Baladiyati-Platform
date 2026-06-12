class UserEntity {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
  });

  /// Placeholder when a user object is needed but profile hasn't been fetched yet.
  const UserEntity.empty()
      : id = 0,
        name = '',
        email = '',
        phone = null,
        avatar = null;
}
