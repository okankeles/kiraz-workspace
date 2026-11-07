enum RoleType { landlord, tenant, agent, admin }

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

  static RoleType fromString(String? role) {
    switch (role?.toUpperCase()) {
      case 'LANDLORD':
        return RoleType.landlord;
      case 'TENANT':
        return RoleType.tenant;
      case 'AGENT':
        return RoleType.agent;
      case 'ADMIN':
        return RoleType.admin;
      default:
        return RoleType.tenant;
    }
  }

  static String toDisplayString(RoleType type) {
    switch (type) {
      case RoleType.landlord:
        return 'Ev Sahibi';
      case RoleType.tenant:
        return 'Kiracı';
      case RoleType.agent:
        return 'Emlak Danışmanı / Acente';
      case RoleType.admin:
        return 'Yönetici';
    }
  }
}
