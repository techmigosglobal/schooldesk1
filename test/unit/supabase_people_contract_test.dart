import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth and users handlers expose avatar upload paths', () {
    final auth = File(
      'supabase/functions/api/handlers/auth.ts',
    ).readAsStringSync();
    final users = File(
      'supabase/functions/api/handlers/users.ts',
    ).readAsStringSync();

    expect(auth, contains('/auth/profile/avatar'));
    expect(users, contains('path.endsWith("/avatar")'));
  });

  test(
    'parent and student link routes are implemented in Supabase handlers',
    () {
      final parent = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();
      final students = File(
        'supabase/functions/api/handlers/students.ts',
      ).readAsStringSync();

      expect(parent, contains(r'^\/parents\/([^/]+)\/students$'));
      expect(parent, contains('admission_numbers'));
      expect(students, contains('sub === "parent"'));
      expect(students, contains('sub === "guardians"'));
    },
  );

  test(
    'users list handler returns top-level pagination fields for Flutter',
    () {
      final users = File(
        'supabase/functions/api/handlers/users.ts',
      ).readAsStringSync();

      expect(users, contains('total: count'));
      expect(users, contains('page_size: size'));
      expect(users, contains('success: true'));
    },
  );

  test(
    'staff handler provisions auth-backed logins instead of writing password into staff table',
    () {
      final staff = File(
        'supabase/functions/api/handlers/staff.ts',
      ).readAsStringSync();

      expect(staff, contains('svc.auth.admin.createUser'));
      expect(staff, contains('svc.auth.admin.updateUserById'));
      expect(staff, contains('svc.auth.admin.deleteUser'));
      expect(staff, contains('username_aliases'));
      expect(staff, contains('linked_type: "staff"'));
      expect(staff, contains('linked_id: staffId'));
      expect(staff, contains('method === "PUT" || method === "PATCH"'));
    },
  );

  test(
    'staff list handler returns top-level pagination fields for Flutter',
    () {
      final staff = File(
        'supabase/functions/api/handlers/staff.ts',
      ).readAsStringSync();

      expect(staff, contains('return cors({'));
      expect(staff, contains('success: true'));
      expect(staff, contains('data: data ?? []'));
      expect(staff, contains('total: count ?? 0'));
      expect(staff, contains('page_size: size'));
      expect(staff, isNot(contains('return ok({\n      data: data ?? []')));
    },
  );

  test(
    'student directory list is server-filtered and uses a lightweight paged DTO',
    () {
      final students = File(
        'supabase/functions/api/handlers/students.ts',
      ).readAsStringSync();

      expect(students, contains('const studentListSelect ='));
      expect(students, contains('url.searchParams.get("search")'));
      expect(students, contains('url.searchParams.get("academic_year_id")'));
      expect(students, contains('studentListSelect'));
      expect(students, contains('has_more: page * size < (count ?? 0)'));
      expect(
        students,
        isNot(
          contains(
            'hydrateStudentDirectory(\n        svc,\n        school,\n        (data ?? [])',
          ),
        ),
      );
    },
  );

  test('Principal student directory keeps paging on the backend', () {
    final screen = File(
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('search: _searchQuery'));
    expect(screen, contains('hasMore'));
    expect(screen, contains('response.data'));
    expect(screen, isNot(contains('while (true) {')));
    expect(screen, isNot(contains('pageSize: 100')));
    expect(screen, isNot(contains('pageSize: 500')));
  });

  test('staff list uses a narrow, searchable server-paged contract', () {
    final staff = File(
      'supabase/functions/api/handlers/staff.ts',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/staff_api.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();

    expect(staff, contains('const staffListSelect ='));
    expect(staff, contains('url.searchParams.get("search")'));
    expect(staff, contains('has_more: page * size < (count ?? 0)'));
    expect(api, contains("queryParams['search']"));
    expect(screen, contains('search: _searchQuery'));
    expect(screen, contains('response.data'));
    expect(screen, isNot(contains('while (true) {')));
    expect(screen, isNot(contains('pageSize: 100')));
    expect(screen, isNot(contains('pageSize: 500')));
  });

  test('user access directory is server-searchable and page based', () {
    final users = File(
      'supabase/functions/api/handlers/users.ts',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/users_api.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/people/presentation/screens/admin_user_access_screen/admin_user_access_screen.dart',
    ).readAsStringSync();

    expect(users, contains('const userListSelect ='));
    expect(users, contains('url.searchParams.get("search")'));
    expect(users, contains('has_more: page * size < (count ?? 0)'));
    expect(api, contains("queryParams['search']"));
    expect(screen, contains('search: _searchQuery'));
    expect(screen, contains('_hasMore'));
    expect(screen, isNot(contains('pageSize: 200')));
  });

  test('guardian directory avoids full student loads and parent N+1 calls', () {
    final students = File(
      'supabase/functions/api/handlers/students.ts',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/users_api.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/people/presentation/screens/guardian_directory_screen/guardian_directory_screen.dart',
    ).readAsStringSync();

    expect(students, contains('path === "/guardians/directory"'));
    expect(students, contains('has_more: page * size < (count ?? 0)'));
    expect(api, contains("'/guardians/directory'"));
    expect(screen, contains('getGuardianDirectory'));
    expect(screen, contains('response.data'));
    expect(screen, isNot(contains('while (true) {')));
    expect(screen, isNot(contains('pageSize: 100')));
    expect(screen, isNot(contains('pageSize: 500')));
    expect(screen, isNot(contains('getParentStudents')));
  });

  test(
    'staff-subject assignment routes are available for staff and classes workflows',
    () {
      final index = File('supabase/functions/api/index.ts').readAsStringSync();
      final academics = File(
        'supabase/functions/api/handlers/academics.ts',
      ).readAsStringSync();

      expect(index, contains('path.startsWith("/staff-subjects")'));
      expect(academics, contains('path.startsWith("/staff-subjects")'));
      expect(academics, contains('svc.from("staff_subjects")'));
      expect(academics, contains('qp(url, "staff_id")'));
      expect(academics, contains('qp(url, "grade_id")'));
      expect(academics, contains('qp(url, "section_id")'));
      expect(academics, contains('method === "DELETE"'));
    },
  );

  test(
    'principal classes handler accepts class-first payloads and full CRUD routes',
    () {
      final principal = File(
        'supabase/functions/api/handlers/principal.ts',
      ).readAsStringSync();

      expect(principal, contains('grade_name'));
      expect(principal, contains('room_number'));
      expect(principal, contains('co_teacher_id'));
      expect(
        principal,
        contains(r'path.match(/^\/principal\/classes\/[^/]+$/)'),
      );
      expect(principal, contains('/principal/classes/import/dry-run'));
      expect(principal, contains('/principal/classes/import'));
      expect(principal, contains('/principal/classes/'));
      expect(principal, isNot(contains('/instructions')));
      expect(principal, contains('method === "PUT"'));
      expect(principal, contains('method === "DELETE"'));
      expect(principal, contains('/principal/subjects'));
      expect(principal, contains('/actions'));
    },
  );

  test('student creation loads freshly-created classes for the class dropdown', () {
    final schoolApi = File(
      'lib/core/network/api_modules/school_api.dart',
    ).readAsStringSync();
    final studentOversight = File(
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final adminStudents = File(
      'lib/features/people/presentation/screens/admin_students_screen/admin_students_screen.dart',
    ).readAsStringSync();

    expect(schoolApi, contains('bool forceRefresh = false'));
    expect(schoolApi, contains("queryParams['refresh_nonce']"));
    expect(studentOversight, contains('getSections(forceRefresh: true)'));
    expect(studentOversight, contains('getGrades(forceRefresh: true)'));
    expect(
      adminStudents,
      contains('forceRefresh: resetPage'),
    );
    expect(adminStudents, contains('forceRefresh: resetPage'));
  });

  test(
    'student creation can create and link a parent login in the same workflow',
    () {
      final adminStudents = File(
        'lib/features/people/presentation/screens/admin_students_screen/admin_students_screen.dart',
      ).readAsStringSync();
      final studentOversight = File(
        'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final users = File(
        'supabase/functions/api/handlers/users.ts',
      ).readAsStringSync();

      expect(adminStudents, contains('shouldCreateParentLogin'));
      expect(adminStudents, contains('Create Parent Login with Password'));
      expect(adminStudents, contains('BackendApiClient.instance.createUser'));
      expect(
        adminStudents,
        contains('BackendApiClient.instance.setStudentParent'),
      );
      expect(studentOversight, contains('input.shouldCreateParentLogin'));
      expect(studentOversight, contains('client.createUser('));
      expect(studentOversight, contains('client.setStudentParent('));
      expect(users, contains('function loginEmail('));
      expect(users, contains('@schooldesk.local'));
      expect(users, contains('syncUsernameAlias'));
    },
  );

  test('parent user payload does not send schema-unknown approval fields', () {
    final usersApi = File(
      'lib/core/network/api_modules/users_api.dart',
    ).readAsStringSync();
    final usersHandler = File(
      'supabase/functions/api/handlers/users.ts',
    ).readAsStringSync();

    expect(usersApi, isNot(contains("'request_principal_approval'")));
    expect(usersHandler, contains('userInsertPayload('));
    expect(
      usersHandler,
      isNot(contains('...rest,\n      email: profileEmail')),
    );
  });

  test(
    'student admission creates guardian profile and link when parent login is created',
    () {
      final studentOversight = File(
        'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final studentsHandler = File(
        'supabase/functions/api/handlers/students.ts',
      ).readAsStringSync();
      final index = File('supabase/functions/api/index.ts').readAsStringSync();

      expect(studentOversight, contains("createRaw('/guardians'"));
      expect(studentOversight, contains('linkGuardianToStudent('));
      expect(index, contains('path.startsWith("/guardians")'));
      expect(studentsHandler, contains('handleGuardians'));
      expect(studentsHandler, contains('svc.from("guardians")'));
      expect(studentsHandler, contains('.maybeSingle()'));
      expect(studentsHandler, contains('svc.from("student_guardians").update'));
      expect(studentsHandler, contains('svc.from("student_guardians").insert'));
    },
  );

  test('principal class hub includes student counts from current sections', () {
    final principal = File(
      'supabase/functions/api/handlers/principal.ts',
    ).readAsStringSync();

    expect(principal, contains('studentCountsBySection'));
    expect(principal, contains('current_section_id'));
    expect(principal, isNot(contains('total_students: 0')));
    expect(principal, contains('student_count'));
  });

  test('students handler matches Flutter student API shape and methods', () {
    final students = File(
      'supabase/functions/api/handlers/students.ts',
    ).readAsStringSync();
    final client = File(
      'lib/core/network/api_modules/students_api.dart',
    ).readAsStringSync();

    expect(client, contains("_dio.put('/students/\$id'"));
    expect(students, contains('return cors({'));
    expect(students, contains('data: data ?? []'));
    expect(students, contains('total: count ?? 0'));
    expect(students, contains('page_size: size'));
    expect(students, contains('method === "PATCH" || method === "PUT"'));
    expect(students, contains('nullableText(payload.current_section_id)'));
    expect(students, contains('["transferred", "transfer"]'));
    expect(students, contains('["withdrawn", "inactive"]'));
    expect(students, contains('parent_accounts: parentAccounts'));
    expect(
      students,
      contains('parent_user_id: text(links[0]?.parent_user_id) || null'),
    );
  });

  test(
    'principal shared handlers expose lesson planner, document, export, and event approval routes',
    () {
      final index = File('supabase/functions/api/index.ts').readAsStringSync();
      final communications = File(
        'supabase/functions/api/handlers/communications.ts',
      ).readAsStringSync();
      final uploads = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();
      final attendance = File(
        'supabase/functions/api/handlers/attendance.ts',
      ).readAsStringSync();
      final fees = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final timetable = File(
        'supabase/functions/api/handlers/timetable.ts',
      ).readAsStringSync();

      expect(index, contains('path.startsWith("/lesson-planners")'));
      expect(index, contains('path.startsWith("/documents")'));

      expect(communications, contains('/lesson-planners/teacher'));
      expect(communications, contains('/lesson-planners/principal'));
      expect(communications, contains('/lesson-planners/parent'));
      expect(communications, contains('/lesson-planners'));
      expect(communications, contains('/complete'));

      expect(uploads, contains('/event-posts/pending'));
      expect(uploads, contains('parts[1] === "approve"'));
      expect(uploads, contains('parts[1] === "reject"'));
      expect(uploads, contains('/documents/requests'));
      expect(uploads, contains('/documents/templates'));
      expect(uploads, contains('/reports/exports'));

      expect(attendance, contains('/attendance/reports/exports'));
      expect(fees, contains('/reports/exports'));

      expect(timetable, contains('/timetable/smart/preview'));
      expect(timetable, contains('/timetable/smart/generate'));
      expect(timetable, contains('/timetable/pre-primary/apply'));
      expect(timetable, contains('/timetable/templates'));
    },
  );

  test('parent document and health routes are backed by Supabase handlers', () {
    final index = File('supabase/functions/api/index.ts').readAsStringSync();
    final uploads = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();
    final medical = File(
      'supabase/functions/api/handlers/medical.ts',
    ).readAsStringSync();

    expect(index, contains('path.startsWith("/student-documents")'));
    expect(index, contains('path.startsWith("/medical-records")'));
    expect(uploads, contains('path === "/student-documents"'));
    expect(uploads, contains('svc.from("student_documents")'));
    expect(uploads, contains('parentCanAccessStudent'));
    expect(medical, contains('path !== "/medical-records"'));
    expect(medical, contains('svc.from("medical_records")'));
    expect(medical, contains('parentCanAccessStudent'));
  });
}
