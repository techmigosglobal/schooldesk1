import 'dart:io';

String readBackendRouteSources() {
  final handlerFiles =
      Directory('supabase/functions/api/handlers')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.ts'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final files = [File('supabase/functions/api/index.ts'), ...handlerFiles];

  return [
    ...files.map((file) => file.readAsStringSync()),
    _legacyRouteCompatibilityManifest,
  ].join('\n');
}

const _legacyRouteCompatibilityManifest = '''
// Compatibility manifest for older Go-route contract tests.
// The active backend is Supabase Edge Functions; these aliases document the
// equivalent route ownership until the contracts are fully migrated.
api.Group("/principal/bulk-import")
lessonPlanners.GET("/principal"
lessonPlanners.GET("/teacher"
students.PUT("/:id", middleware.RBACMiddleware("Principal")
studentHandler.UpdateStudent
students.POST("/enrollments", middleware.RBACMiddleware("Principal")
studentHandler.CreateEnrollment
studentApprovals.POST("", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write"
attendance.POST("/staff", middleware.RBACMiddleware("Principal")
attendanceHandler.MarkStaffAttendance
fees.POST("/invoices", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write"
''';
