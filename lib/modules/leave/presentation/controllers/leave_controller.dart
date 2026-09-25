import 'package:flutter/material.dart';

import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/modules/leave/domain/entities/leave_request.dart';
import 'package:schooldesk1/modules/leave/domain/repositories/leave_repository.dart';

/// State management controller for leave request operations.
class LeaveController extends ChangeNotifier {
  final LeaveRepository _repository;

  LeaveController(this._repository);

  // ─── State ────────────────────────────────────────────────────────────────

  List<LeaveRequest> _requests = [];
  bool _isLoading = false;
  RepositoryState<List<LeaveRequest>> _state = const RepositoryState.empty();
  String _statusFilter = '';

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<LeaveRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _state.error?.toString();
  bool get hasError => _state.isError;
  bool get isEmpty => !_isLoading && _requests.isEmpty && !hasError;

  List<LeaveRequest> get pendingRequests =>
      _requests.where((r) => r.status == 'Pending').toList();

  List<LeaveRequest> get approvedRequests =>
      _requests.where((r) => r.status == 'Approved').toList();

  List<LeaveRequest> get rejectedRequests =>
      _requests.where((r) => r.status == 'Rejected').toList();

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> loadRequests({String? requesterId, String? role}) async {
    _setLoading(true);
    _clearError();

    final result = await _repository.getLeaveRequests(
      requesterId: requesterId,
      status: _statusFilter.isEmpty ? null : _statusFilter,
      role: role,
    );

    result.when(
      success: (requests) {
        _requests = requests;
        _setLoading(false);
      },
      failure: (f) {
        _setError(f.message);
        _setLoading(false);
      },
    );
  }

  Future<bool> submitRequest(LeaveRequest request) async {
    _setLoading(true);
    final result = await _repository.submitLeaveRequest(request);
    return result.when(
      success: (r) {
        _requests.insert(0, r);
        _setLoading(false);
        notifyListeners();
        return true;
      },
      failure: (f) {
        _setError(f.message);
        _setLoading(false);
        return false;
      },
    );
  }

  Future<bool> approveRequest(String id, String approvedBy) async {
    final result = await _repository.approveLeaveRequest(
      id: id,
      approvedBy: approvedBy,
    );
    return result.when(
      success: (r) {
        final idx = _requests.indexWhere((req) => req.id == id);
        if (idx != -1) _requests[idx] = r;
        notifyListeners();
        return true;
      },
      failure: (f) {
        _setError(f.message);
        return false;
      },
    );
  }

  Future<bool> rejectRequest(
    String id,
    String rejectedBy,
    String remark,
  ) async {
    final result = await _repository.rejectLeaveRequest(
      id: id,
      rejectedBy: rejectedBy,
      remark: remark,
    );
    return result.when(
      success: (r) {
        final idx = _requests.indexWhere((req) => req.id == id);
        if (idx != -1) _requests[idx] = r;
        notifyListeners();
        return true;
      },
      failure: (f) {
        _setError(f.message);
        return false;
      },
    );
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void clearError() => _clearError();

  void _setLoading(bool value) {
    _isLoading = value;
    _state = value
        ? RepositoryState<List<LeaveRequest>>.loading(
            data: _requests,
            source: _requests.isEmpty
                ? RepositorySource.empty
                : RepositorySource.cache,
          )
        : RepositoryState<List<LeaveRequest>>(
            data: _requests,
            source: RepositorySource.remote,
            error: _state.error,
            phase: _requests.isEmpty
                ? RepositoryPhase.empty
                : RepositoryPhase.ready,
          );
    notifyListeners();
  }

  void _setError(String message) {
    _state = RepositoryState<List<LeaveRequest>>(
      data: _requests.isEmpty ? null : _requests,
      source: _requests.isEmpty
          ? RepositorySource.empty
          : RepositorySource.cache,
      isStale: _requests.isNotEmpty,
      error: message,
    );
    notifyListeners();
  }

  void _clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }
}
