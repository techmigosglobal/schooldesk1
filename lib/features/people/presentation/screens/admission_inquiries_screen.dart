import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class AdmissionInquiriesScreen extends StatefulWidget {
  const AdmissionInquiriesScreen({super.key});

  @override
  State<AdmissionInquiriesScreen> createState() =>
      _AdmissionInquiriesScreenState();
}

class _AdmissionInquiriesScreenState extends State<AdmissionInquiriesScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = BackendApiClient.instance.getRawList('/admission-inquiries');
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Admission Inquiries',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => setState(
            () => _future = BackendApiClient.instance.getRawList(
              '/admission-inquiries',
            ),
          ),
        ),
      ],
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load admission inquiries: ${snapshot.error}',
              ),
            );
          }
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return const Center(child: Text('No admission inquiries yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.markunread_outlined),
                  ),
                  title: Text(
                    '${row['parent_name'] ?? ''} · ${row['program'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${row['child_name'] ?? 'Child not named'} · ${row['child_age'] ?? ''}\n${row['phone'] ?? ''} · ${row['email'] ?? ''}',
                  ),
                  isThreeLine: true,
                  onTap: () => _showDetail(context, row),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Admission inquiry',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              for (final key in const [
                'parent_name',
                'phone',
                'email',
                'child_name',
                'child_age',
                'program',
                'message',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${key.replaceAll('_', ' ')}: ${row[key] ?? '—'}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
