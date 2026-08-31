import 'organisation_models.dart';
import 'people_models.dart';

enum EastAppPermission {
  reportIntelligenceView('REPORT_INTELLIGENCE_VIEW'),
  reportOperationsAccess('REPORT_OPERATIONS_ACCESS'),
  salesReportAccess('SALES_REPORT_ACCESS'),
  reportReview('REPORT_REVIEW'),
  knowledgeAuditView('KNOWLEDGE_AUDIT_VIEW'),
  dailyTaskView('DAILY_TASK_VIEW'),
  dailyTaskContribute('DAILY_TASK_CONTRIBUTE'),
  dailyTaskViewAll('DAILY_TASK_VIEW_ALL'),
  dailyTaskManage('DAILY_TASK_MANAGE'),
  dailyTaskRate('DAILY_TASK_RATE');

  final String apiValue;

  const EastAppPermission(this.apiValue);

  static EastAppPermission? tryParse(Object? value) {
    for (final permission in values) {
      if (permission.apiValue == value) return permission;
    }
    return null;
  }
}

class EastAppSession {
  final String token;
  final EastAppTenant tenant;
  final EastAppUser user;
  final Set<EastAppPermission> permissions;

  const EastAppSession({
    required this.token,
    required this.tenant,
    required this.user,
    required this.permissions,
  });

  factory EastAppSession.fromCurrentUserJson({
    required String token,
    required Map<String, dynamic> json,
  }) {
    final granted = <EastAppPermission>{};
    final values = json['permissions'];
    if (values is List) {
      for (final value in values) {
        final permission = EastAppPermission.tryParse(value);
        if (permission != null) granted.add(permission);
      }
    }

    return EastAppSession(
      token: token,
      tenant: EastAppTenant.fromJson(
        json['tenant'] as Map<String, dynamic>,
      ),
      user: EastAppUser.fromJson(
        json['user'] as Map<String, dynamic>,
      ),
      permissions: Set.unmodifiable(granted),
    );
  }

  bool can(EastAppPermission permission) => permissions.contains(permission);

  EastAppSession copyWith({
    String? token,
    EastAppTenant? tenant,
    EastAppUser? user,
    Set<EastAppPermission>? permissions,
  }) {
    return EastAppSession(
      token: token ?? this.token,
      tenant: tenant ?? this.tenant,
      user: user ?? this.user,
      permissions: permissions ?? this.permissions,
    );
  }
}
