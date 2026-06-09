import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/operation_ownership_policy.dart';
import 'package:schooldesk1/routes/app_routes.dart';

void main() {
  OperationOwnershipMatrix loadMatrix() {
    final file = File(OperationOwnershipMatrix.assetPath);
    final decoded = jsonDecode(file.readAsStringSync()) as Map;
    final matrix = OperationOwnershipMatrix.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    matrix.validate();
    return matrix;
  }

  test(
    'admin principal ownership matrix covers all required Admin modules',
    () {
      final matrix = loadMatrix();
      const requiredModules = {
        'students',
        'staff',
        'attendance_operations',
        'fees',
        'timetable',
        'exams',
        'communication',
        'helpdesk',
        'documents',
        'user_access',
        'reports',
        'academic_info',
      };

      expect(
        matrix.modules.map((module) => module.key).toSet(),
        requiredModules,
      );
      expect(
        matrix.statuses,
        containsAll([
          'draft',
          'submitted',
          'principal_review',
          'changes_requested',
          'approved',
          'rejected',
          'applied',
          'cancelled',
        ]),
      );
    },
  );

  test('admin can submit operational requests but cannot finalize them', () {
    final matrix = loadMatrix();

    for (final module in matrix.modules) {
      expect(module.admin.view, isTrue, reason: module.key);
      expect(module.admin.finalApprove, isFalse, reason: module.key);
      expect(module.admin.finalReject, isFalse, reason: module.key);
      expect(module.admin.directPublish, isFalse, reason: module.key);
      expect(module.admin.deleteActiveRecord, isFalse, reason: module.key);
      expect(matrix.can(module.key, 'admin', 'approve'), isFalse);
      expect(matrix.can(module.key, 'admin', 'reject'), isFalse);
      expect(matrix.can(module.key, 'admin', 'publish'), isFalse);
      expect(matrix.can(module.key, 'admin', 'delete'), isFalse);
    }
  });

  test('principal owns final approval and review actions', () {
    final matrix = loadMatrix();
    final operationalModules = matrix.modules.where(
      (module) => module.key != 'reports',
    );

    for (final module in operationalModules) {
      expect(module.principal.view, isTrue, reason: module.key);
      expect(module.principal.finalApprove, isTrue, reason: module.key);
      expect(module.principal.finalReject, isTrue, reason: module.key);
      expect(matrix.can(module.key, 'principal', 'approve'), isTrue);
      expect(matrix.can(module.key, 'principal', 'reject'), isTrue);
    }
  });

  test('matrix Admin routes are registered application routes', () {
    final matrix = loadMatrix();
    final registeredRoutes = AppRoutes.routes.keys.toSet();

    for (final module in matrix.modules) {
      expect(
        registeredRoutes,
        contains(module.frontendRoute),
        reason: '${module.key} route must be registered',
      );
    }
  });
}
