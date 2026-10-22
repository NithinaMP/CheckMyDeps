/// Role inside ONE organisation. Order matters: later = more privileged.
enum OrgRole {
  developer,
  lead,
  admin;

  static OrgRole? tryParse(Object? value) {
    if (value is! String) return null;
    for (final role in OrgRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }

  String get label {
    switch (this) {
      case OrgRole.admin:
        return 'Admin';
      case OrgRole.lead:
        return 'Lead';
      case OrgRole.developer:
        return 'Developer';
    }
  }

  /// UI hint only. The backend re-checks every request.
  bool atLeast(OrgRole minimum) => index >= minimum.index;
}

class Organization {
  const Organization({required this.id, required this.name, this.createdAt});

  final String id;
  final String name;
  final DateTime? createdAt;
}

/// An organisation plus the signed-in user's role in it, as reported by the backend.
class OrgMembership {
  const OrgMembership({required this.organization, required this.role});

  final Organization organization;
  final OrgRole role;

  String get id => organization.id;
  String get name => organization.name;

  factory OrgMembership.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final role = OrgRole.tryParse(json['role']);
    if (id is! String || id.isEmpty || name is! String || role == null) {
      throw const FormatException('Invalid organisation payload');
    }
    final created = json['created_at'];
    return OrgMembership(
      organization: Organization(
        id: id,
        name: name,
        createdAt: created is String ? DateTime.tryParse(created) : null,
      ),
      role: role,
    );
  }
}
