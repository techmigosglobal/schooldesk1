import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/modules/communication/domain/notification_broadcast_repository.dart';
import 'package:schooldesk1/modules/communication/data/api_notification_broadcast_repository.dart';

class PrincipalSendNotificationScreen extends StatefulWidget {
  const PrincipalSendNotificationScreen({super.key, this.repository});
  final NotificationBroadcastRepository? repository;
  @override
  State<PrincipalSendNotificationScreen> createState() =>
      _PrincipalSendNotificationScreenState();
}

class _PrincipalSendNotificationScreenState
    extends State<PrincipalSendNotificationScreen> {
  late NotificationBroadcastRepository _repo;
  late final BackendApiClient _api;
  late String _scope;
  String? _accountId, _role;
  int _scopeEpoch = 0;
  BuildContext? _confirmationContext;
  final _title = TextEditingController(),
      _message = TextEditingController(),
      _search = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _roles = <String>{'parent'}, _selected = <String>{};
  final _people = <Map<String, dynamic>>[], _history = <Map<String, dynamic>>[];
  bool _all = false, _busy = false, _loading = false, _showHistory = false;
  bool _recipientsReady = false, _loadFailed = false;
  int _page = 0, _total = 0, _request = 0, _historyPage = 0;
  String? _key, _error, _notice;
  Timer? _debounce;
  static const _roleLabels = {
    'parent': 'Parents',
    'teacher': 'Teachers / co-teachers',
    'coordinator': 'Coordinators',
    'principal': 'Principals',
  };
  @override
  void initState() {
    super.initState();
    _api = widget.repository is ApiNotificationBroadcastRepository
        ? (widget.repository! as ApiNotificationBroadcastRepository).api
        : BackendApiClient.instance;
    _scope = _api.offlineAccountKey;
    _accountId = _api.currentUserId;
    _role = _api.currentRoleName;
    _repo = widget.repository ?? ApiNotificationBroadcastRepository(_api);
    _api.addListener(_scopeChanged);
    _load();
  }

  @override
  void dispose() {
    _api.removeListener(_scopeChanged);
    _debounce?.cancel();
    _title.dispose();
    _message.dispose();
    _search.dispose();
    super.dispose();
  }

  void _scopeChanged() {
    final scope = _api.offlineAccountKey;
    final account = _api.currentUserId;
    final role = _api.currentRoleName;
    if (!mounted ||
        (scope == _scope && account == _accountId && role == _role)) {
      return;
    }
    final accountChanged = account != _accountId;
    final confirmation = _confirmationContext;
    _confirmationContext = null;
    if (confirmation != null &&
        confirmation.mounted &&
        ModalRoute.of(confirmation)?.isCurrent == true) {
      Navigator.of(confirmation).pop(false);
    }
    _debounce?.cancel();
    setState(() {
      _scope = scope;
      _accountId = account;
      _role = role;
      ++_scopeEpoch;
      ++_request;
      _busy = false;
      _loading = false;
      _loadFailed = false;
      _recipientsReady = false;
      _people.clear();
      _history.clear();
      _selected.clear();
      _roles
        ..clear()
        ..add('parent');
      _search.clear();
      _all = false;
      _page = _total = _historyPage = 0;
      _key = null;
      _error = null;
      _showHistory = false;
      _notice = 'School or account changed. Review recipients before sending.';
      if (accountChanged) {
        _title.clear();
        _message.clear();
      }
      if (widget.repository == null ||
          widget.repository is ApiNotificationBroadcastRepository) {
        _repo = ApiNotificationBroadcastRepository(_api);
      }
    });
    if (role == 'principal') unawaited(_load());
  }

  void _changed() {
    _key = null;
  }

  Future<void> _load({bool more = false}) async {
    _debounce?.cancel();
    final request = ++_request;
    final scope = _api.offlineAccountKey;
    final history = _showHistory;
    setState(() {
      _loading = true;
      _loadFailed = false;
      if (!history) _recipientsReady = false;
      _error = null;
    });
    try {
      if (history) {
        final page = more ? _historyPage + 1 : 1;
        final data = await _repo.history(page: page);
        if (!mounted ||
            request != _request ||
            scope != _api.offlineAccountKey) {
          return;
        }
        setState(() {
          if (!more) _history.clear();
          _history.addAll(List<Map<String, dynamic>>.from(data['items'] ?? []));
          _historyPage = page;
        });
      } else {
        final page = more ? _page + 1 : 1;
        final data = await _repo.recipients(
          roles: Set.of(_roles),
          search: _search.text.trim(),
          page: page,
        );
        if (!mounted ||
            request != _request ||
            scope != _api.offlineAccountKey) {
          return;
        }
        setState(() {
          if (!more) _people.clear();
          _people.addAll(List<Map<String, dynamic>>.from(data['items'] ?? []));
          _page = page;
          _total = (data['total'] as num?)?.toInt() ?? 0;
          _recipientsReady = true;
        });
      }
    } on Object {
      if (mounted && request == _request && scope == _api.offlineAccountKey) {
        setState(() {
          _loadFailed = true;
          _error = history
              ? 'Sent history could not be loaded. Please try again.'
              : 'Recipients could not be loaded. Check your connection and try again before sending.';
        });
      }
    } finally {
      if (mounted && request == _request && scope == _api.offlineAccountKey) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    if (_scope != _api.offlineAccountKey) {
      _scopeChanged();
      return;
    }
    if (_busy || _loading || !_recipientsReady) return;
    if (!_form.currentState!.validate()) return;
    final epoch = _scopeEpoch;
    final scope = _api.offlineAccountKey;
    final count = _all ? _total : _selected.length;
    if (count == 0) {
      setState(() => _error = 'Select at least one active recipient.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        _confirmationContext = context;
        return AlertDialog(
          title: const Text('Send notification?'),
          scrollable: true,
          content: Text(
            '${_title.text.trim()}\n\n${_message.text.trim()}\n\nRecipients: $count${_all ? ' — all active users in the selected roles' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    _confirmationContext = null;
    if (confirmed != true ||
        !mounted ||
        epoch != _scopeEpoch ||
        scope != _api.offlineAccountKey ||
        !_recipientsReady ||
        _loading) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _key ??= _newKey();
    try {
      final result = await _repo.send(
        key: _key!,
        title: _title.text.trim(),
        message: _message.text.trim(),
        roles: Set.of(_roles),
        all: _all,
        userIds: Set.of(_selected),
      );
      if (!mounted || epoch != _scopeEpoch || scope != _api.offlineAccountKey) {
        return;
      }
      setState(() {
        _notice =
            'Notification saved for ${result['recipient_count']} recipients. Push delivery is queued.';
        _title.clear();
        _message.clear();
        _selected.clear();
        _key = null;
        _showHistory = true;
      });
      await _load();
    } on Object {
      if (mounted && epoch == _scopeEpoch && scope == _api.offlineAccountKey) {
        setState(
          () => _error =
              'We could not confirm sending. Check your connection and retry unchanged to avoid duplicates.',
        );
      }
    } finally {
      if (mounted && epoch == _scopeEpoch) setState(() => _busy = false);
    }
  }

  String _newKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Widget _historyCard(Map<String, dynamic> row) {
    final delivery = Map<String, dynamic>.from(row['delivery'] ?? {});
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['title']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${row['message']}'),
            const SizedBox(height: 8),
            Text('${row['recipient_count']} recipients • ${row['created_at']}'),
            const SizedBox(height: 8),
            Text(
              'Queued: ${delivery['queued'] ?? 0} • Accepted by push service: ${delivery['push_accepted'] ?? 0}\nNo registered device: ${delivery['no_device'] ?? 0} • Failed: ${delivery['failed'] ?? 0} • Other outcomes: ${delivery['other'] ?? 0}',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SchoolDeskModuleScaffold(
    title: 'Send Notification',
    subtitle: 'Choose school recipients and send an update',
    actions: [
      IconButton(
        tooltip: 'Refresh',
        onPressed: _busy || _loading ? null : () => _load(),
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Compose', softWrap: true),
              icon: Icon(Icons.edit_notifications_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Sent history', softWrap: true),
              icon: Icon(Icons.history),
            ),
          ],
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          selected: {_showHistory},
          onSelectionChanged: _busy
              ? null
              : (value) {
                  setState(() => _showHistory = value.single);
                  _load();
                },
        ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_notice!),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_loadFailed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh),
              label: Text(_showHistory ? 'Retry history' : 'Retry recipients'),
            ),
          ),
        if (_loading) const LinearProgressIndicator(),
        const SizedBox(height: 16),
        if (_showHistory) ...[
          if (!_loading && !_loadFailed && _history.isEmpty)
            const Text('No notifications sent yet.'),
          ..._history.map(_historyCard),
          if (_history.length == _historyPage * 20 && _history.isNotEmpty)
            TextButton(
              onPressed: _loading ? null : () => _load(more: true),
              child: const Text('Load more history'),
            ),
        ] else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (_) => _changed(),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Enter a title' : null,
                ),
                TextFormField(
                  controller: _message,
                  enabled: !_busy,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Message'),
                  onChanged: (_) => _changed(),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Enter a message' : null,
                ),
                const SizedBox(height: 12),
                const Text('Recipient roles'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final role in _roleLabels.entries)
                      FilterChip(
                        label: Text(role.value),
                        selected: _roles.contains(role.key),
                        onSelected: _busy
                            ? null
                            : (selected) {
                                if (!selected && _roles.length == 1) return;
                                setState(() {
                                  selected
                                      ? _roles.add(role.key)
                                      : _roles.remove(role.key);
                                  _selected.clear();
                                  _search.clear();
                                  _changed();
                                });
                                _load();
                              },
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Select all in chosen roles'),
                  subtitle: const Text(
                    'Includes active users across every page',
                  ),
                  value: _all,
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _all = value;
                            _search.clear();
                            _changed();
                          });
                          _load();
                        },
                ),
                Text('${_all ? _total : _selected.length} recipients selected'),
                if (!_all) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _search,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Search people',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      setState(() {
                        _recipientsReady = false;
                        ++_request;
                      });
                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () => _load(),
                      );
                    },
                  ),
                  for (final person in _people)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${person['name']}'),
                      subtitle: Text(
                        _roleLabels[person['role_name']] ??
                            '${person['role_name']}',
                      ),
                      value: _selected.contains(person['id']),
                      onChanged: _busy || _loading || !_recipientsReady
                          ? null
                          : (selected) {
                              setState(() {
                                selected == true
                                    ? _selected.add('${person['id']}')
                                    : _selected.remove('${person['id']}');
                                _changed();
                              });
                            },
                    ),
                  if (_people.length < _total)
                    TextButton(
                      onPressed: _loading ? null : () => _load(more: true),
                      child: const Text('Load more people'),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy || _loading || !_recipientsReady
                      ? null
                      : _send,
                  icon: Icon(_busy ? Icons.hourglass_top : Icons.send_outlined),
                  label: Text(_busy ? 'Sending…' : 'Review and send'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
