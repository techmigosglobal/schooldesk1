import 'dart:async';

import 'package:flutter/material.dart';
import 'package:schooldesk1/core/paging/paged_list_controller.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/modules/people/data/api_admission_inquiry_repository.dart';
import 'package:schooldesk1/modules/people/domain/admission_inquiry_repository.dart';

class AdmissionInquiriesScreen extends StatefulWidget {
  const AdmissionInquiriesScreen({super.key, this.repository});

  final AdmissionInquiryRepository? repository;

  @override
  State<AdmissionInquiriesScreen> createState() =>
      _AdmissionInquiriesScreenState();
}

class _AdmissionInquiriesScreenState extends State<AdmissionInquiriesScreen> {
  late final PagedListController<Map<String, dynamic>> _paging;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  AdmissionInquiryRepository get _repository =>
      widget.repository ?? ApiAdmissionInquiryRepository.legacyDefault;

  final RepositoryState<Object> _state = const RepositoryState<Object>(
    data: Object(),
    source: RepositorySource.remote,
  );

  @override
  void initState() {
    super.initState();
    _paging = PagedListController<Map<String, dynamic>>(
      loadPage: ({required page, required pageSize}) => _repository.loadPage(
        search: _searchController.text,
        page: page,
        pageSize: pageSize,
      ),
      itemKey: (row) => '${row['id'] ?? ''}',
    );
    _paging.load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _paging.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _paging.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Admission Inquiries',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _paging.refresh,
        ),
      ],
      body: SchoolDeskRepositoryStateView<Object>(
        state: _state,
        onRetry: _paging.refresh,
        data: (_) => AnimatedBuilder(
          animation: _paging,
          builder: (context, _) {
            final rows = _paging.items;
            final hasError = _paging.error != null;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search parent, child, phone, or email',
                    ),
                  ),
                ),
                if (_paging.isStale)
                  MaterialBanner(
                    content: const Text(
                      'Showing cached inquiries. Retry to refresh.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: _paging.refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                if (hasError && rows.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Admission inquiries are unavailable.'),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _paging.refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_paging.status == PagedListStatus.loading &&
                    rows.isEmpty)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (rows.isEmpty)
                  const Expanded(
                    child: Center(child: Text('No admission inquiries yet.')),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length + (_paging.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        if (index == rows.length) {
                          return OutlinedButton(
                            onPressed: _paging.isBusy ? null : _paging.loadMore,
                            child: Text(
                              _paging.isBusy ? 'Loading…' : 'Load more',
                            ),
                          );
                        }
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
                    ),
                  ),
              ],
            );
          },
        ),
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
