import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';

void main() {
  test('accepts the backend announcement body and audience fields', () {
    final announcement = AnnouncementModel.fromJson({
      'id': 'announcement-1',
      'school_id': 'school-1',
      'title': 'Welcome QA',
      'body': 'Seed announcement for deterministic tests.',
      'audience': 'all',
      'priority': 'normal',
      'created_by': null,
      'published_at': '2026-10-02T09:07:37.846234+00:00',
    });

    expect(announcement.content, 'Seed announcement for deterministic tests.');
    expect(announcement.targetAudience, 'all');
    expect(announcement.createdBy, '');
    expect(announcement.isUrgent, isFalse);
  });

  test('retains the canonical UI field names when supplied', () {
    final announcement = AnnouncementModel.fromJson({
      'id': 'announcement-2',
      'school_id': 'school-1',
      'title': 'Urgent notice',
      'content': 'Bring records.',
      'target_audience': 'teachers',
      'is_urgent': true,
      'created_by': 'staff-1',
      'published_at': '2026-10-02T09:07:37.846234+00:00',
    });

    expect(announcement.content, 'Bring records.');
    expect(announcement.targetAudience, 'teachers');
    expect(announcement.createdBy, 'staff-1');
    expect(announcement.isUrgent, isTrue);
  });
}
