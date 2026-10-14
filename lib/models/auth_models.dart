import 'organisation_models.dart';
import 'people_models.dart';

enum FlowPermission {
  reportIntelligenceView('REPORT_INTELLIGENCE_VIEW'),
  reportOperationsAccess('REPORT_OPERATIONS_ACCESS'),
  salesReportAccess('SALES_REPORT_ACCESS'),
  reportReview('REPORT_REVIEW'),
  knowledgeAuditView('KNOWLEDGE_AUDIT_VIEW'),
  taskView('TASK_VIEW'),
  taskContribute('TASK_CONTRIBUTE'),
  taskViewAll('TASK_VIEW_ALL'),
  taskManage('TASK_MANAGE'),
  taskRate('TASK_RATE'),
  storageAdmin('STORAGE_ADMIN');

  final String apiValue;

  const FlowPermission(this.apiValue);

  static FlowPermission? tryParse(Object? value) {
    for (final permission in values) {
      if (permission.apiValue == value) return permission;
    }
    return null;
  }
}

class FlowSession {
  final String token;
  final FlowTenant tenant;
  final FlowUser user;
  final Set<FlowPermission> permissions;

  const FlowSession({
    required this.token,
    required this.tenant,
    required this.user,
    required this.permissions,
  });

  factory FlowSession.fromCurrentUserJson({
    required String token,
    required Map<String, dynamic> json,
  }) {
    final granted = <FlowPermission>{};
    final values = json['permissions'];
    if (values is List) {
      for (final value in values) {
        final permission = FlowPermission.tryParse(value);
        if (permission != null) granted.add(permission);
      }
    }

    return FlowSession(
      token: token,
      tenant: FlowTenant.fromJson(
        json['tenant'] as Map<String, dynamic>,
      ),
      user: FlowUser.fromJson(
        json['user'] as Map<String, dynamic>,
      ),
      permissions: Set.unmodifiable(granted),
    );
  }

  bool can(FlowPermission permission) => permissions.contains(permission);

  FlowSession copyWith({
    String? token,
    FlowTenant? tenant,
    FlowUser? user,
    Set<FlowPermission>? permissions,
  }) {
    return FlowSession(
      token: token ?? this.token,
      tenant: tenant ?? this.tenant,
      user: user ?? this.user,
      permissions: permissions ?? this.permissions,
    );
  }
}
