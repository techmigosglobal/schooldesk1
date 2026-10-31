import 'package:flutter/material.dart';

/// Student identity stays stable through transfers and promotions. Each saved
/// record displays its original class and academic year, not today's class.
class TeacherStudentAttendanceHistorySheet extends StatefulWidget {
  const TeacherStudentAttendanceHistorySheet({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.loadHistory,
  });

  final String studentId;
  final String studentName;
  final Future<List<Map<String, dynamic>>> Function(String) loadHistory;

  @override
  State<TeacherStudentAttendanceHistorySheet> createState() =>
      _TeacherStudentAttendanceHistorySheetState();
}

class _TeacherStudentAttendanceHistorySheetState
    extends State<TeacherStudentAttendanceHistorySheet> {
  List<Map<String, dynamic>>? _records;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TeacherStudentAttendanceHistorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _records = null;
      _failed = false;
    });
    try {
      final records = List<Map<String, dynamic>>.of(
        await widget.loadHistory(widget.studentId),
      );
      if (!mounted || generation != _generation) return;
      records.sort((a, b) {
        final aSession = _map(a['session']);
        final bSession = _map(b['session']);
        return '${bSession['date'] ?? ''}'.compareTo(
          '${aSession['date'] ?? ''}',
        );
      });
      setState(() => _records = records);
    } on Object catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _failed = true);
    }
  }

  static Map<String, dynamic> _map(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  Widget _record(Map<String, dynamic> record) {
    final session = _map(record['session']);
    final section = _map(session['section']);
    final grade = _map(section['grade']);
    final year = _map(session['academic_year']);
    final classLabel = [
      grade['grade_name'],
      section['section_name'],
    ].where((value) => value != null && '$value'.trim().isNotEmpty).join(' - ');
    final rawStatus = '${record['status'] ?? ''}'.toLowerCase();
    final status = switch (rawStatus) {
      'present' => 'Present',
      'absent' => 'Absent',
      'late' => 'Late',
      'leave' => 'Leave',
      'half_day' => 'Half day',
      _ => 'Recorded',
    };
    final date = '${session['date'] ?? record['marked_at'] ?? ''}'
        .split('T')
        .first;
    final labels = [
      if (classLabel.isNotEmpty) classLabel else 'Original class unavailable',
      if ('${year['year_label'] ?? ''}'.isNotEmpty) '${year['year_label']}',
    ];
    return ListTile(
      isThreeLine: true,
      leading: Icon(
        rawStatus == 'absent' ? Icons.cancel_outlined : Icons.event_available,
      ),
      title: Text(date.isEmpty ? 'Date unavailable' : date),
      subtitle: Text('${labels.join(' · ')}\n$status'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.studentName} — Attendance history',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close attendance history',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Includes previous classes and academic years. Past registers keep their original class and date.',
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (records != null && records.isNotEmpty)
              SliverList.builder(
                itemCount: records.length,
                itemBuilder: (_, index) => _record(records[index]),
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: _failed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Unable to load attendance history. Check your connection and retry.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : records == null
                    ? const Center(child: CircularProgressIndicator())
                    : const Center(child: Text('No attendance recorded yet.')),
              ),
          ],
        ),
      ),
    );
  }
}
