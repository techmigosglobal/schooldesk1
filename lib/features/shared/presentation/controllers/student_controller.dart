import 'package:flutter/material.dart';

import 'package:schooldesk1/features/shared/domain/entities/student.dart';
import 'package:schooldesk1/features/shared/domain/repositories/student_repository.dart';

/// State management controller for student operations.
/// Used by Admin, Principal, and Teacher screens.
/// Extend with ChangeNotifier for setState-free UI updates.
class StudentController extends ChangeNotifier {
  final StudentRepository _repository;

  StudentController(this._repository);

  // ─── State ────────────────────────────────────────────────────────────────

  List<Student> _students = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedClass = '';
  String _selectedSection = '';

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<Student> get students => _students;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedClass => _selectedClass;
  String get selectedSection => _selectedSection;
  bool get hasError => _error != null;
  bool get isEmpty => !_isLoading && _students.isEmpty && _error == null;

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> loadStudents() async {
    _setLoading(true);
    _clearError();

    final result = await _repository.getStudents(
      className: _selectedClass.isEmpty ? null : _selectedClass,
      section: _selectedSection.isEmpty ? null : _selectedSection,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    result.when(
      success: (students) {
        _students = students;
        _setLoading(false);
      },
      failure: (failure) {
        _setError(failure.message);
        _setLoading(false);
      },
    );
  }

  Future<bool> createStudent(Student student) async {
    _setLoading(true);
    final result = await _repository.createStudent(student);
    return result.when(
      success: (s) {
        _students.insert(0, s);
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

  Future<bool> updateStudent(Student student) async {
    final result = await _repository.updateStudent(student);
    return result.when(
      success: (s) {
        final idx = _students.indexWhere((st) => st.id == s.id);
        if (idx != -1) _students[idx] = s;
        notifyListeners();
        return true;
      },
      failure: (f) {
        _setError(f.message);
        return false;
      },
    );
  }

  Future<bool> deleteStudent(String id) async {
    final result = await _repository.deleteStudent(id);
    return result.when(
      success: (_) {
        _students.removeWhere((s) => s.id == id);
        notifyListeners();
        return true;
      },
      failure: (f) {
        _setError(f.message);
        return false;
      },
    );
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    loadStudents();
  }

  void setClassFilter(String className) {
    _selectedClass = className;
    notifyListeners();
    loadStudents();
  }

  void setSectionFilter(String section) {
    _selectedSection = section;
    notifyListeners();
    loadStudents();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedClass = '';
    _selectedSection = '';
    loadStudents();
  }

  void clearError() => _clearError();

  // ─── Private helpers ──────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
