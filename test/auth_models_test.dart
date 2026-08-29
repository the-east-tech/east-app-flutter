import 'package:east_app/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses granted permissions from the existing current-user payload', () {
    final session = EastAppSession.fromCurrentUserJson(
      token: 'token',
      json: {
        'tenant': {
          'id': 'tenant-1',
          'companyCode': 'EAST',
          'businessName': 'The East',
          'employeeIdPrefix': 'E',
        },
        'user': {
          'id': 'user-1',
          'employeeId': 'E0001',
          'fullName': 'Manager',
          'phoneE164': '+60123456789',
          'profilePhotoKey': null,
          'birthDate': null,
          'startDate': null,
          'endDate': null,
          'active': true,
          'role': {
            'id': 'role-1',
            'systemKey': 'MANAGER',
            'name': 'Manager',
            'active': true,
          },
          'createdAt': '2026-08-28T00:00:00Z',
          'updatedAt': '2026-08-28T00:00:00Z',
        },
        'permissions': [
          'REPORT_INTELLIGENCE_VIEW',
          'DAILY_TASK_MANAGE',
          'UNKNOWN_FUTURE_PERMISSION',
        ],
      },
    );

    expect(
      session.can(EastAppPermission.reportIntelligenceView),
      isTrue,
    );
    expect(session.can(EastAppPermission.dailyTaskManage), isTrue);
    expect(session.can(EastAppPermission.reportReview), isFalse);
    expect(session.permissions, hasLength(2));
  });

  test('missing permissions fail closed', () {
    expect(EastAppPermission.tryParse(null), isNull);
    expect(EastAppPermission.tryParse('NOT_GRANTED'), isNull);
  });
}
