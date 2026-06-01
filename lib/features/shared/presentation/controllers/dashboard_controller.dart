import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

/// Dashboard KPI data model.
class DashboardKpi {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String? route;

  const DashboardKpi({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.route,
  });
}

/// Base dashboard controller — shared logic for all 4 role dashboards.
abstract class BaseDashboardController extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  List<DashboardKpi> _kpis = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<DashboardKpi> get kpis => _kpis;
  bool get hasError => _error != null;

  Future<void> loadDashboard();

  void setKpis(List<DashboardKpi> kpis) {
    _kpis = kpis;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Principal dashboard controller.
class PrincipalDashboardController extends BaseDashboardController {
  PrincipalDashboardController();

  int _totalStudents = 0;
  int _totalTeachers = 0;
  double _attendanceRate = 0;
  double _feeCollectionRate = 0;
  int _pendingComplaints = 0;
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _alerts = [];

  int get totalStudents => _totalStudents;
  int get totalTeachers => _totalTeachers;
  double get attendanceRate => _attendanceRate;
  double get feeCollectionRate => _feeCollectionRate;
  int get pendingComplaints => _pendingComplaints;
  List<Map<String, dynamic>> get recentActivity => _recentActivity;
  List<Map<String, dynamic>> get alerts => _alerts;

  @override
  Future<void> loadDashboard() async {
    setLoading(true);
    clearError();

    try {
      final api = BackendApiClient.instance;
      final students = await api.getStudents(page: 1, pageSize: 1);
      final teachers = await api.getStaff(page: 1, pageSize: 1);
      final fees = await api.getInvoices();
      final notifications = await api.getNotifications();

      _totalStudents = students.total;
      _totalTeachers = teachers.total;
      _pendingComplaints = notifications
          .where((c) => '${c['category'] ?? ''}' == 'complaint')
          .where((c) => c['is_read'] != true)
          .length;

      if (fees.isNotEmpty) {
        final paid = fees
            .where((f) => '${f['status'] ?? ''}'.toLowerCase() == 'paid')
            .length;
        _feeCollectionRate = (paid / fees.length) * 100;
      } else {
        _feeCollectionRate = 0;
      }

      _attendanceRate = 0;

      _alerts = [
        if (_pendingComplaints > 0)
          {
            'type': 'warning',
            'message':
                '$_pendingComplaints pending complaints require attention',
            'icon': 'warning',
          },
        {
          'type': 'info',
          'message':
              'Fee collection at ${_feeCollectionRate.toStringAsFixed(1)}%',
          'icon': 'info',
        },
      ];

      _recentActivity = notifications.take(5).map((n) {
        return {
          'action': n['title'] ?? n['body'] ?? 'Notification',
          'time': n['sent_at'] ?? n['created_at'] ?? '',
          'icon': 'info',
        };
      }).toList();

      setKpis([
        DashboardKpi(
          title: 'Total Students',
          value: '$_totalStudents',
          icon: Icons.people,
          color: Colors.blue,
          route: '/student-oversight-screen',
        ),
        DashboardKpi(
          title: 'Total Teachers',
          value: '$_totalTeachers',
          icon: Icons.school,
          color: Colors.green,
          route: '/staff-management-screen',
        ),
        DashboardKpi(
          title: 'Attendance Rate',
          value: '${_attendanceRate.toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          color: Colors.orange,
          route: '/admin-attendance-screen',
        ),
        DashboardKpi(
          title: 'Fee Collection',
          value: '${_feeCollectionRate.toStringAsFixed(1)}%',
          icon: Icons.account_balance_wallet,
          color: Colors.purple,
          route: '/fee-monitoring-screen',
        ),
        DashboardKpi(
          title: 'Complaints',
          value: '$_pendingComplaints',
          subtitle: 'Pending',
          icon: Icons.report_problem,
          color: Colors.red,
          route: '/complaint-management-screen',
        ),
      ]);
    } catch (e) {
      setError('Failed to load dashboard data. Please try again.');
    } finally {
      setLoading(false);
    }
  }
}

/// Admin dashboard controller.
class AdminDashboardController extends BaseDashboardController {
  AdminDashboardController();

  List<Map<String, dynamic>> _systemAlerts = [];
  List<Map<String, dynamic>> _quickStats = [];

  List<Map<String, dynamic>> get systemAlerts => _systemAlerts;
  List<Map<String, dynamic>> get quickStats => _quickStats;

  @override
  Future<void> loadDashboard() async {
    setLoading(true);
    clearError();

    try {
      final api = BackendApiClient.instance;
      final students = await api.getStudents(page: 1, pageSize: 1);
      final teachers = await api.getStaff(page: 1, pageSize: 1);
      final fees = await api.getInvoices();
      final leaveRequests = await api.getLeaveApplications();

      final pendingLeaves = leaveRequests
          .where((r) => r.status.toLowerCase() == 'pending')
          .length;
      final pendingFees = fees
          .where((f) => '${f['status'] ?? ''}'.toLowerCase() != 'paid')
          .length;

      _systemAlerts = [
        if (pendingLeaves > 0)
          {
            'type': 'warning',
            'message': '$pendingLeaves leave requests pending approval',
          },
        {'type': 'info', 'message': '$pendingFees fee dues outstanding'},
      ];

      _quickStats = [
        {'label': 'Students', 'value': '${students.total}'},
        {'label': 'Teachers', 'value': '${teachers.total}'},
        {'label': 'Pending Dues', 'value': '$pendingFees'},
        {'label': 'Leave Requests', 'value': '$pendingLeaves'},
      ];

      setKpis([
        DashboardKpi(
          title: 'Students',
          value: '${students.total}',
          icon: Icons.people,
          color: Colors.blue,
          route: '/admin-students-screen',
        ),
        DashboardKpi(
          title: 'Teachers',
          value: '${teachers.total}',
          icon: Icons.school,
          color: Colors.green,
          route: '/admin-teachers-screen',
        ),
        DashboardKpi(
          title: 'Pending Dues',
          value: '$pendingFees',
          icon: Icons.payment,
          color: Colors.orange,
          route: '/admin-fees-screen',
        ),
        DashboardKpi(
          title: 'Leave Requests',
          value: '$pendingLeaves',
          icon: Icons.event_busy,
          color: Colors.red,
          route: '/admin-attendance-screen',
        ),
      ]);
    } catch (e) {
      setError('Failed to load admin dashboard.');
    } finally {
      setLoading(false);
    }
  }
}
