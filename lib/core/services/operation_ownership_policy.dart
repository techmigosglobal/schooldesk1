import 'dart:convert';

import 'package:flutter/services.dart';

class OperationPermission {
  final bool view;
  final bool createDraft;
  final bool submitForApproval;
  final bool editPendingRequest;
  final bool cancelOwnPendingRequest;
  final bool finalApprove;
  final bool finalReject;
  final bool directPublish;
  final bool deleteActiveRecord;

  const OperationPermission({
    required this.view,
    required this.createDraft,
    required this.submitForApproval,
    required this.editPendingRequest,
    required this.cancelOwnPendingRequest,
    required this.finalApprove,
    required this.finalReject,
    required this.directPublish,
    required this.deleteActiveRecord,
  });

  factory OperationPermission.fromJson(Map<String, dynamic> json) {
    return OperationPermission(
      view: json['view'] == true,
      createDraft: json['create_draft'] == true,
      submitForApproval: json['submit_for_approval'] == true,
      editPendingRequest: json['edit_pending_request'] == true,
      cancelOwnPendingRequest: json['cancel_own_pending_request'] == true,
      finalApprove: json['final_approve'] == true,
      finalReject: json['final_reject'] == true,
      directPublish: json['direct_publish'] == true,
      deleteActiveRecord: json['delete_active_record'] == true,
    );
  }

  bool allows(String action) {
    switch (_normalize(action)) {
      case 'view':
        return view;
      case 'create_draft':
      case 'createdraft':
      case 'draft':
        return createDraft;
      case 'submit_for_approval':
      case 'submitforapproval':
      case 'submit':
        return submitForApproval;
      case 'edit_pending_request':
      case 'editpendingrequest':
      case 'edit_pending':
        return editPendingRequest;
      case 'cancel_own_pending_request':
      case 'cancelownpendingrequest':
      case 'cancel':
        return cancelOwnPendingRequest;
      case 'final_approve':
      case 'finalapprove':
      case 'approve':
        return finalApprove;
      case 'final_reject':
      case 'finalreject':
      case 'reject':
        return finalReject;
      case 'direct_publish':
      case 'directpublish':
      case 'publish':
        return directPublish;
      case 'delete_active_record':
      case 'deleteactiverecord':
      case 'delete':
        return deleteActiveRecord;
      default:
        return false;
    }
  }
}

class ModuleOwnership {
  final String key;
  final String label;
  final String frontendRoute;
  final String backendResource;
  final String entityType;
  final String riskLevel;
  final OperationPermission admin;
  final OperationPermission principal;

  const ModuleOwnership({
    required this.key,
    required this.label,
    required this.frontendRoute,
    required this.backendResource,
    required this.entityType,
    required this.riskLevel,
    required this.admin,
    required this.principal,
  });

  factory ModuleOwnership.fromJson(Map<String, dynamic> json) {
    return ModuleOwnership(
      key: _string(json['key']),
      label: _string(json['label']),
      frontendRoute: _string(json['frontend_route']),
      backendResource: _string(json['backend_resource']),
      entityType: _string(json['entity_type']),
      riskLevel: _string(json['risk_level']),
      admin: OperationPermission.fromJson(
        Map<String, dynamic>.from(json['admin'] as Map),
      ),
      principal: OperationPermission.fromJson(
        Map<String, dynamic>.from(json['principal'] as Map),
      ),
    );
  }

  OperationPermission? permissionForRole(String role) {
    switch (_normalize(role)) {
      case 'admin':
        return admin;
      case 'principal':
        return principal;
      default:
        return null;
    }
  }
}

class OperationOwnershipMatrix {
  static const assetPath =
      'school-backend/internal/policy/admin_principal_ownership_matrix.json';

  final int version;
  final List<String> statuses;
  final List<ModuleOwnership> modules;

  const OperationOwnershipMatrix({
    required this.version,
    required this.statuses,
    required this.modules,
  });

  factory OperationOwnershipMatrix.fromJson(Map<String, dynamic> json) {
    return OperationOwnershipMatrix(
      version: json['version'] as int? ?? 0,
      statuses: (json['statuses'] as List? ?? const [])
          .map((value) => _string(value))
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      modules: (json['modules'] as List? ?? const [])
          .map(
            (value) => ModuleOwnership.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  static Future<OperationOwnershipMatrix> loadFromAsset({
    AssetBundle? bundle,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    return OperationOwnershipMatrix.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  ModuleOwnership? module(String key) {
    final normalized = _normalize(key);
    for (final module in modules) {
      if (_normalize(module.key) == normalized ||
          _normalize(module.label) == normalized) {
        return module;
      }
    }
    return null;
  }

  bool can(String moduleKey, String role, String action) {
    return module(moduleKey)?.permissionForRole(role)?.allows(action) ?? false;
  }

  void validate() {
    if (version <= 0) {
      throw StateError('Ownership matrix version is required.');
    }
    if (statuses.isEmpty) {
      throw StateError('Ownership matrix statuses are required.');
    }
    final seen = <String>{};
    for (final module in modules) {
      final key = _normalize(module.key);
      if (key.isEmpty || !seen.add(key)) {
        throw StateError('Invalid or duplicate module key: ${module.key}');
      }
      if (module.label.isEmpty ||
          module.frontendRoute.isEmpty ||
          module.backendResource.isEmpty ||
          module.entityType.isEmpty) {
        throw StateError('Module ${module.key} is missing metadata.');
      }
      if (module.admin.finalApprove ||
          module.admin.finalReject ||
          module.admin.directPublish ||
          module.admin.deleteActiveRecord) {
        throw StateError('Admin has final rights for ${module.key}.');
      }
    }
  }
}

String _string(Object? value) => (value ?? '').toString().trim();

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(' ', '_');
