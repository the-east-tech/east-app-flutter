import 'app_models.dart';

class EastAppRole {
  final String id;
  final String? systemKey;
  final String name;
  final bool active;
  final int? assignedUsers;

  const EastAppRole({
    required this.id,
    required this.systemKey,
    required this.name,
    required this.active,
    this.assignedUsers,
  });

  factory EastAppRole.fromJson(Map<String, dynamic> json) {
    return EastAppRole(
      id: json['id'] as String,
      systemKey: json['systemKey'] as String?,
      name: json['name'] as String,
      active: json['active'] as bool,
      assignedUsers: (json['assignedUsers'] as num?)?.toInt(),
    );
  }

  bool get isBuiltIn => systemKey != null;
  bool get isOwner => systemKey == 'OWNER';
  bool get isHead => systemKey == 'OWNER' || systemKey == 'HEAD';

  UserRole get appRole {
    switch (systemKey) {
      case 'OWNER':
      case 'HEAD':
        return UserRole.head;
      case 'MANAGER':
        return UserRole.manager;
      default:
        return UserRole.staff;
    }
  }
}

class EastAppUser {
  final String id;
  final String employeeId;
  final String fullName;
  final String phoneE164;
  final String? profilePhotoKey;
  final DateTime? birthDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;
  final EastAppRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EastAppUser({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.phoneE164,
    required this.profilePhotoKey,
    required this.birthDate,
    required this.startDate,
    required this.endDate,
    required this.active,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EastAppUser.fromJson(Map<String, dynamic> json) {
    return EastAppUser(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      fullName: json['fullName'] as String,
      phoneE164: json['phoneE164'] as String,
      profilePhotoKey: json['profilePhotoKey'] as String?,
      birthDate: _parseDate(json['birthDate']),
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      active: json['active'] as bool,
      role: EastAppRole.fromJson(json['role'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }
}
