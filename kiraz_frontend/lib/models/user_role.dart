enum RoleType { landlord, tenant, admin }

class UserRole {
  final String id;
  final String userName;
  final String propertyName;
  final RoleType roleType;

  const UserRole({
    required this.id,
    required this.userName,
    required this.propertyName,
    required this.roleType,
  });
}
