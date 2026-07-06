import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

/// A unified "Today's Highlights" card that surfaces birthday wishes and
/// health alerts for the current role. Placed at the top of each dashboard.
class TodaysHighlightsCard extends StatefulWidget {
  final String role;

  const TodaysHighlightsCard({super.key, required this.role});

  @override
  State<TodaysHighlightsCard> createState() => _TodaysHighlightsCardState();
}

class _TodaysHighlightsCardState extends State<TodaysHighlightsCard> {
  NotificationService? _service;
  SharedPreferences? _prefs;
  bool _expanded = false;
  bool _stateReady = false;
  String _activeSignature = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  static bool _alreadyRefreshedToday = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await _triggerBirthdayAlertsIfNeeded(prefs);
    final svc = await NotificationService.getInstance();
    // Only force-refresh notifications once per app session to avoid
    // hammering the /notifications endpoint on every widget rebuild.
    if (!_alreadyRefreshedToday) {
      _alreadyRefreshedToday = true;
      await svc.refresh();
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _service = svc;
    });
  }

  Future<void> _triggerBirthdayAlertsIfNeeded(SharedPreferences prefs) async {
    final api = BackendApiClient.instance;
    if (!api.isAuthenticated) return;
    final today = DateTime.now();
    final key =
        'birthday_alerts_synced_${today.year}_${today.month}_${today.day}_${widget.role}';
    if (prefs.getBool(key) == true) return;
    await api.triggerBirthdayAlerts().catchError((_) => <String, dynamic>{});
    await prefs.setBool(key, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    final allNotifs = _service?.getNotificationsForRole(widget.role) ?? [];
    final today = DateTime.now();

    final birthdayNotifs = allNotifs.where((n) {
      return n.category == NotificationCategory.birthday &&
          _isSameDay(n.timestamp, today);
    }).toList();

    final healthNotifs = allNotifs.where((n) {
      return (n.category == NotificationCategory.health ||
              n.category == NotificationCategory.healthAlert) &&
          _isSameDay(n.timestamp, today);
    }).toList();

    // Also check reference_type for birthday notifications from the backend
    final birthdayByRef = allNotifs.where((n) {
      return (n.referenceType.contains('birthday') ||
              n.referenceType.contains('birthday_wish')) &&
          _isSameDay(n.timestamp, today);
    }).toList();

    // Also check reference_type for health reminders
    final healthByRef = allNotifs.where((n) {
      return (n.referenceType.contains('health_reminder') ||
              n.referenceType.contains('health')) &&
          _isSameDay(n.timestamp, today);
    }).toList();

    final combinedBirthdays = _mergeUnique([
      ...birthdayNotifs,
      ...birthdayByRef,
    ]);
    final combinedHealth = _mergeUnique([...healthNotifs, ...healthByRef]);
    final todaysHighlights = [...combinedBirthdays, ...combinedHealth]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (todaysHighlights.isEmpty) {
      return const SizedBox.shrink();
    }

    final signature = _signatureFor(todaysHighlights);
    _syncExpandedState(today: today, signature: signature);
    if (!_stateReady) {
      return const SizedBox.shrink();
    }
    final unreadCount = todaysHighlights.where((item) => !item.isRead).length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius.card),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withAlpha(60),
            theme.colorScheme.secondaryContainer.withAlpha(40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(40)),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: Text(
                    "Today's Highlights",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _formatDate(today),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: _expanded
                      ? 'Collapse today highlights'
                      : 'Expand today highlights',
                  child: IconButton(
                    tooltip: _expanded
                        ? 'Collapse today highlights'
                        : 'Expand today highlights',
                    onPressed: () => _toggleExpanded(today, signature),
                    icon: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                  ),
                ),
              ],
            ),
            if (unreadCount > 0) ...[
              SizedBox(height: tokens.spacing.sm),
              Text(
                unreadCount == 1
                    ? '1 new highlight'
                    : '$unreadCount new highlights',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_expanded && combinedBirthdays.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.md),
              _BirthdayAlertSection(
                notifications: combinedBirthdays.take(5).toList(),
                onAcknowledge: (notifId) async {
                  await _service?.markAsRead(notifId);
                  if (mounted) setState(() {});
                },
              ),
            ],
            if (_expanded && combinedHealth.isNotEmpty) ...[
              if (combinedBirthdays.isNotEmpty)
                SizedBox(height: tokens.spacing.sm),
              _HealthAlertSection(
                notifications: combinedHealth.take(5).toList(),
                onAcknowledge: (notifId) async {
                  await _service?.markAsRead(notifId);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<AppNotification> _mergeUnique(List<AppNotification> items) {
    final seen = <String>{};
    final result = <AppNotification>[];
    for (final item in items) {
      if (seen.add(item.id)) {
        result.add(item);
      }
    }
    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _storageKey(DateTime date) =>
      'todays_highlights_${widget.role}_${date.year}_${date.month}_${date.day}';

  String _signatureFor(List<AppNotification> items) {
    final ids = items.map((item) => item.id).toList()..sort();
    return ids.join('|');
  }

  void _syncExpandedState({
    required DateTime today,
    required String signature,
  }) {
    if (_prefs == null) return;
    if (_stateReady && _activeSignature == signature) return;
    final prefs = _prefs!;
    final key = _storageKey(today);
    final lastSignature = prefs.getString('${key}_signature') ?? '';
    final storedExpanded = prefs.getBool('${key}_expanded') ?? false;
    final hasNewHighlights = signature.isNotEmpty && signature != lastSignature;
    _activeSignature = signature;
    _stateReady = true;
    _expanded = hasNewHighlights || storedExpanded;
    if (hasNewHighlights) {
      prefs.setString('${key}_signature', signature);
      prefs.setBool('${key}_expanded', true);
    }
  }

  Future<void> _toggleExpanded(DateTime today, String signature) async {
    final next = !_expanded;
    setState(() {
      _expanded = next;
      _stateReady = true;
      _activeSignature = signature;
    });
    final prefs = _prefs;
    if (prefs == null) return;
    final key = _storageKey(today);
    await prefs.setString('${key}_signature', signature);
    await prefs.setBool('${key}_expanded', next);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _BirthdayAlertSection extends StatelessWidget {
  final List<AppNotification> notifications;
  final Future<void> Function(String notifId) onAcknowledge;

  const _BirthdayAlertSection({
    required this.notifications,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🎂', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              'Birthdays (${notifications.length})',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE91E63),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...notifications.map(
          (notification) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _BirthdayAlertTile(
              notification: notification,
              onAcknowledge: onAcknowledge,
            ),
          ),
        ),
      ],
    );
  }
}

class _BirthdayAlertTile extends StatelessWidget {
  final AppNotification notification;
  final Future<void> Function(String notifId) onAcknowledge;

  const _BirthdayAlertTile({
    required this.notification,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acknowledged = notification.isRead;
    const pink = Color(0xFFE91E63);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: acknowledged
            ? theme.colorScheme.surface.withAlpha(100)
            : theme.colorScheme.surface.withAlpha(180),
        borderRadius: BorderRadius.circular(8),
        border: acknowledged
            ? null
            : Border.all(color: pink.withAlpha(50), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            acknowledged ? Icons.check_circle_rounded : Icons.cake_rounded,
            size: 16,
            color: acknowledged ? Colors.green : pink,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: acknowledged
                        ? TextDecoration.lineThrough
                        : null,
                    color: acknowledged
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                if (notification.body.isNotEmpty)
                  Text(
                    notification.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (!acknowledged)
            _AcknowledgeButton(onPressed: () => onAcknowledge(notification.id))
          else
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Seen',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthAlertSection extends StatelessWidget {
  final List<AppNotification> notifications;
  final Future<void> Function(String notifId) onAcknowledge;

  const _HealthAlertSection({
    required this.notifications,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              'Health Alerts (${notifications.length})',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...notifications.map(
          (n) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _HealthAlertTile(
              notification: n,
              onAcknowledge: onAcknowledge,
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthAlertTile extends StatelessWidget {
  final AppNotification notification;
  final Future<void> Function(String notifId) onAcknowledge;

  const _HealthAlertTile({
    required this.notification,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acknowledged = notification.isRead;
    final orange = const Color(0xFFFF9800);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: acknowledged
            ? theme.colorScheme.surface.withAlpha(100)
            : theme.colorScheme.surface.withAlpha(180),
        borderRadius: BorderRadius.circular(8),
        border: acknowledged
            ? null
            : Border.all(color: orange.withAlpha(50), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            acknowledged
                ? Icons.check_circle_rounded
                : Icons.medical_services_rounded,
            size: 16,
            color: acknowledged ? Colors.green : orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: acknowledged
                        ? TextDecoration.lineThrough
                        : null,
                    color: acknowledged
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                if (notification.body.isNotEmpty)
                  Text(
                    notification.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (!acknowledged)
            _AcknowledgeButton(onPressed: () => onAcknowledge(notification.id))
          else
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Seen',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AcknowledgeButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  const _AcknowledgeButton({required this.onPressed});

  @override
  State<_AcknowledgeButton> createState() => _AcknowledgeButtonState();
}

class _AcknowledgeButtonState extends State<_AcknowledgeButton>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnim.value, child: child),
      child: InkWell(
        onTap: _loading ? null : _handleTap,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _loading
                ? const Color(0xFFFF9800).withAlpha(60)
                : const Color(0xFFFF9800).withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: _loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFFFF9800),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Color(0xFFFF9800),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Acknowledge',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF9800),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
