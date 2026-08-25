import 'package:east_app/models/daily_task_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses an immutable submitted Daily Task record', () {
    final record = DailyTaskRecord.fromJson({
      'id': 'record-1',
      'templateId': 'template-1',
      'tagId': 'tag-1',
      'tagName': 'Kitchen',
      'taskDate': '2026-08-24',
      'title': 'Kitchen closing check',
      'instruction': 'Close safely.',
      'requiredPhotoCount': 1,
      'photoCount': 1,
      'status': 'SUBMITTED',
      'checklistItems': [
        {
          'id': 'check-1',
          'position': 0,
          'description': 'Switch off equipment',
          'completed': true,
          'completedBy': _person,
          'completedAt': '2026-08-24T13:40:12.345Z',
        },
      ],
      'photos': [
        {
          'id': 'photo-1',
          'photoStorageKey': 'photo-key.jpg',
          'submittedBy': _person,
          'submittedAt': '2026-08-24T13:41:22.456Z',
        },
      ],
      'requirementsMet': true,
      'submittedBy': _person,
      'submittedAt': '2026-08-24T13:42:34.567Z',
      'rating': null,
      'ratingComment': null,
      'ratedBy': null,
      'ratedAt': null,
      'canContribute': false,
      'canSubmit': false,
      'canRate': true,
      'activity': [
        {
          'id': 'audit-1',
          'action': 'TASK_SUBMITTED',
          'details': 'Task submitted for rating',
          'actor': _person,
          'occurredAt': '2026-08-24T13:42:34.567Z',
        },
      ],
    });

    expect(record.status, DailyTaskStatus.submitted);
    expect(record.requirementsMet, isTrue);
    expect(record.canContribute, isFalse);
    expect(record.canRate, isTrue);
    expect(record.photos.single.submittedAt.millisecond, 456);
    expect(record.submittedAt?.millisecond, 567);
  });

  test('Daily Task overview calculates completion from done tasks', () {
    const overview = DailyTaskOverview(
      total: 4,
      pending: 1,
      submitted: 1,
      done: 2,
    );

    expect(overview.completionRate, 0.5);
  });

  test('parses a manually loaded Daily Task date range', () {
    final result = DailyTaskList.fromJson({
      'taskDate': '2026-08-24',
      'dateFrom': '2026-08-18',
      'dateTo': '2026-08-24',
      'overview': {
        'total': 0,
        'pending': 0,
        'submitted': 0,
        'done': 0,
      },
      'records': <Object>[],
    });

    expect(result.dateFrom, DateTime(2026, 8, 18));
    expect(result.dateTo, DateTime(2026, 8, 24));
  });
}

const _person = {
  'userId': 'user-1',
  'fullName': 'Example Staff',
  'employeeId': 'E0002',
  'role': 'STAFF_1',
};
