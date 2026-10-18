import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/communication/presentation/screens/chat_workspace/chat_workspace_controller.dart';
import 'package:schooldesk1/features/communication/presentation/screens/chat_workspace/chat_workspace_screen.dart';
import 'package:schooldesk1/modules/communication/domain/chat_workspace_repository.dart';

class FakeWorkspaceRepository implements ChatWorkspaceRepository {
  @override
  String accountScope = 'school:account:teacher';
  @override
  String currentUserId = 'me';
  @override
  String currentRole = 'teacher';
  final events = StreamController<void>.broadcast();
  final connections = StreamController<ChatConnectionStatus>.broadcast();
  final drafts = <String, String>{};
  final sends = <String>[];
  final messageLoads = <String, Completer<Map<String, dynamic>>>{};
  bool failSend = false, queueSend = false;
  Completer<void>? draftSaveGate;
  final reads = <String>[];
  String lastMessageMode = '';
  Future<Map<String, dynamic>> Function(bool monitor, int page)?
  conversationLoader;
  Future<Map<String, dynamic>> Function(String mode, String sentAt, String id)?
  messageLoader;
  List<Map<String, dynamic>> rows = [
    thread('one', 'Riya'),
    thread('two', 'Nisha'),
  ];
  List<Map<String, dynamic>> contactRows = [
    {
      'id': 'parent-one',
      'name': 'Riya',
      'role': 'parent',
      'type': 'principal_parent',
      'student_id': 'child-one',
      'student_name': 'Aarav',
      'class_label': 'Nursery A',
    },
  ];
  List<Map<String, dynamic>> pending = [];
  @override
  Stream<void> get invalidations => events.stream;
  @override
  Stream<ChatConnectionStatus> get connectionChanges => connections.stream;
  @override
  Future<List<Map<String, dynamic>>> loadChildren() async => [
    {'id': 'child-one', 'name': 'Aarav', 'class_label': 'Nursery A'},
    {'id': 'child-two', 'name': 'Meera', 'class_label': 'LKG B'},
  ];
  @override
  Future<List<Map<String, dynamic>>> loadContacts({
    String studentId = '',
  }) async => contactRows;
  @override
  Future<Map<String, dynamic>> loadConversation(String conversationId) async =>
      rows.firstWhere((row) => row['id'] == conversationId);
  @override
  Future<Map<String, dynamic>> loadConversations({
    bool monitor = false,
    String studentId = '',
    String search = '',
    String type = '',
    int page = 1,
    int pageSize = 50,
  }) async =>
      conversationLoader?.call(monitor, page) ??
      {'data': rows, 'has_more': false};
  @override
  Future<Map<String, dynamic>> loadMessages({
    required String conversationId,
    String mode = 'latest',
    String cursorSentAt = '',
    String cursorId = '',
    int pageSize = 50,
  }) async {
    lastMessageMode = mode;
    return messageLoader?.call(mode, cursorSentAt, cursorId) ??
        messageLoads[conversationId]?.future ??
        {'data': <Map<String, dynamic>>[], 'has_more': false};
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String clientMessageId,
    required String body,
    String conversationId = '',
    Map<String, dynamic> contact = const {},
  }) async {
    sends.add(clientMessageId);
    if (failSend) throw StateError('offline');
    if (queueSend) {
      return {'queued': true, 'client_message_id': clientMessageId};
    }
    return {
      'conversation': {
        ...thread(conversationId.isEmpty ? 'created' : conversationId, 'Riya'),
      },
      'message': {
        'id': 'server-${sends.length}',
        'client_message_id': clientMessageId,
        'body': body,
        'sender_user_id': 'me',
        'sent_at': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }

  @override
  Future<List<Map<String, dynamic>>> pendingMessages() async => pending;
  @override
  Future<void> markRead({
    required String conversationId,
    String throughSentAt = '',
    String throughId = '',
  }) async {
    reads.add(conversationId);
  }

  @override
  Future<int> unreadCount({bool monitor = false}) async => 0;
  @override
  Future<String> readDraft(String key) async => drafts[key] ?? '';
  @override
  Future<void> saveDraft(String key, String body) async {
    drafts[key] = body;
    await draftSaveGate?.future;
  }

  @override
  Future<void> watch({String conversationId = ''}) async {
    connections.add(ChatConnectionStatus.connected);
  }

  @override
  Future<void> refreshConnection() async {}
  @override
  Future<void> dispose() async {
    await events.close();
    await connections.close();
  }
}

Map<String, dynamic> thread(String id, String parent) => {
  'id': id,
  'type': 'parent_teacher',
  'parent_id': 'parent-$id',
  'teacher_id': 'teacher',
  'student_id': 'child-$id',
  'parent': {'name': parent},
  'teacher': {'name': 'Ananya'},
  'student_name': 'Aarav',
  'class_label': 'Nursery A',
  'last_message': 'Hello',
  'unread_count': 1,
};

void main() {
  test('late thread reads cannot replace the newly selected thread', () async {
    final repo = FakeWorkspaceRepository();
    final controller = ChatWorkspaceController(repo, 'teacher');
    await controller.start();
    final old = Completer<Map<String, dynamic>>();
    repo.messageLoads['one'] = old;
    final opening = controller.openThread(repo.rows.first);
    await Future<void>.delayed(Duration.zero);
    await controller.openThread(repo.rows.last);
    old.complete({
      'data': [
        {
          'id': 'old',
          'body': 'Wrong thread',
          'sent_at': '2026-01-01T10:00:00Z',
        },
      ],
    });
    await opening;
    expect(controller.selected?['id'], 'two');
    expect(controller.messages, isEmpty);
    controller.dispose();
    await repo.dispose();
  });
  test(
    'two identical bodies retain separate identities and retry uses the same UUID',
    () async {
      final repo = FakeWorkspaceRepository();
      final controller = ChatWorkspaceController(repo, 'teacher');
      await controller.start();
      await controller.openThread(repo.rows.first);
      controller.updateDraft('Same message');
      await controller.send();
      controller.updateDraft('Same message');
      await controller.send();
      expect(controller.messages.length, 2);
      expect(repo.sends.toSet().length, 2);
      repo.failSend = true;
      controller.updateDraft('Retry message');
      await controller.send();
      final failed = controller.messages.firstWhere(
        (e) => e['_delivery'] == 'Failed',
      );
      final uuid = failed['client_message_id'];
      repo.failSend = false;
      await controller.send(retry: failed);
      expect(repo.sends.last, uuid);
      expect(controller.messages.length, 3);
      expect(
        controller.messages.any((e) => e['_delivery'] == 'Failed'),
        isFalse,
      );
      controller.dispose();
      await repo.dispose();
    },
  );
  test(
    'drafts persist per conversation and nested direct returns to monitor',
    () async {
      final repo = FakeWorkspaceRepository();
      final controller = ChatWorkspaceController(repo, 'principal');
      await controller.start();
      await controller.changeMonitor(true);
      await controller.openThread(repo.rows.first);
      controller.updateDraft('Monitor reply');
      await controller.openThread({
        ...repo.contactRows.first,
        '_contact': true,
      }, nested: true);
      controller.updateDraft('Direct reply');
      await controller.closeThread();
      expect(controller.selected?['id'], 'one');
      expect(controller.monitor, isTrue);
      expect(controller.draft, 'Monitor reply');
      await controller.closeThread();
      expect(controller.selected, isNull);
      expect(repo.drafts.values, contains('Direct reply'));
      controller.dispose();
      await repo.dispose();
    },
  );
  test(
    'queued outbox survives opening a conversation and account switch clears it',
    () async {
      final repo = FakeWorkspaceRepository()
        ..pending = [
          {
            'client_message_id': 'queued-id',
            'conversation_id': 'one',
            'body': 'Saved offline',
            'created_at': '2026-01-01T10:00:00Z',
            'status': 'pending',
          },
        ];
      final controller = ChatWorkspaceController(repo, 'teacher');
      await controller.start();
      await controller.openThread(repo.rows.first);
      expect(controller.messages.single['_delivery'], 'Queued');
      repo.accountScope = 'different-account';
      await controller.refresh();
      expect(controller.selected, isNull);
      expect(controller.messages, isEmpty);
      controller.dispose();
      await repo.dispose();
    },
  );

  test(
    'account switch during draft persistence cancels unsent transport',
    () async {
      final repo = FakeWorkspaceRepository();
      final controller = ChatWorkspaceController(repo, 'teacher');
      await controller.start();
      await controller.openThread(repo.rows.first);
      controller.updateDraft('Original account message');
      final gate = Completer<void>();
      repo.draftSaveGate = gate;
      final sending = controller.send();
      await Future<void>.delayed(Duration.zero);
      repo.accountScope = 'different-account';
      await controller.refresh();
      gate.complete();
      await sending;
      expect(repo.sends, isEmpty);
      expect(controller.messages, isEmpty);
      controller.dispose();
      await repo.dispose();
    },
  );

  test(
    'older pages use before cursor and refresh does not read messages while scrolled away',
    () async {
      final repo = FakeWorkspaceRepository();
      final first = Completer<Map<String, dynamic>>()
        ..complete({
          'data': [
            {'id': 'm1', 'body': 'Initial', 'sent_at': '2026-01-01T10:00:00Z'},
          ],
          'has_more': true,
          'next_cursor': {'sent_at': '2026-01-01T10:00:00Z', 'id': 'm1'},
        });
      repo.messageLoads['one'] = first;
      final controller = ChatWorkspaceController(repo, 'teacher');
      await controller.start();
      await controller.openThread(repo.rows.first);
      await Future<void>.delayed(Duration.zero);
      final initialReadCount = repo.reads.length;
      controller.threadVisibleAtBottom = false;
      repo.messageLoads['one'] = Completer<Map<String, dynamic>>()
        ..complete({
          'data': [
            {
              'id': 'm2',
              'body': 'New message',
              'sent_at': '2026-01-01T11:00:00Z',
            },
          ],
          'has_more': false,
        });
      await controller.refresh();
      expect(repo.reads.length, initialReadCount);
      await controller.loadOlder();
      expect(repo.lastMessageMode, 'before');
      expect(controller.messages.length, 2);
      await controller.markCurrentRead();
      expect(repo.reads.length, initialReadCount + 1);
      controller.dispose();
      await repo.dispose();
    },
  );

  test(
    'reconnect catches up all 51 messages before latest page without gaps',
    () async {
      final repo = FakeWorkspaceRepository();
      Map<String, dynamic> message(int index) => {
        'id': 'm$index',
        'client_message_id': 'c$index',
        'body': 'Message $index',
        'sent_at': DateTime.utc(2026, 1, 1, 10, index).toIso8601String(),
      };
      repo.messageLoader = (mode, sent, id) async => {
        'data': [message(0)],
        'has_more': false,
      };
      final controller = ChatWorkspaceController(repo, 'teacher');
      await controller.start();
      await controller.openThread(repo.rows.first);
      final afterCursors = <String>[];
      repo.messageLoader = (mode, sent, id) async {
        if (mode == 'after') {
          afterCursors.add(id);
          return id == 'm0'
              ? {
                  'data': List.generate(50, (i) => message(i + 1)),
                  'has_more': true,
                  'next_cursor': {
                    'sent_at': message(50)['sent_at'],
                    'id': 'm50',
                  },
                }
              : {
                  'data': [message(51)],
                  'has_more': false,
                };
        }
        return {
          'data': List.generate(50, (i) => message(i + 2)),
          'has_more': true,
          'next_cursor': {'sent_at': message(2)['sent_at'], 'id': 'm2'},
        };
      };
      await controller.refresh();
      expect(controller.messages.length, 52);
      expect(afterCursors, ['m0', 'm50']);
      expect(controller.messages.map((m) => m['id']).toSet().length, 52);
      controller.dispose();
      await repo.dispose();
    },
  );
  test(
    'queued first-contact promotes and reconciles by client UUID after delivery',
    () async {
      final repo = FakeWorkspaceRepository()..rows = [];
      final contact = {
        ...repo.contactRows.first,
        'parent_id': 'parent-one',
        'leader_id': 'me',
      };
      repo.contactRows = [contact];
      repo.pending = [
        {
          'type': 'principal_parent',
          'parent_id': 'parent-one',
          'leader_id': 'me',
          'student_id': 'child-one',
          'client_message_id': 'queued-contact',
          'body': 'Hello',
          'created_at': '2026-01-01T10:00:00Z',
          'status': 'pending',
        },
      ];
      final controller = ChatWorkspaceController(repo, 'principal');
      await controller.start();
      await controller.openThread({...contact, '_contact': true});
      expect(controller.messages.single['_delivery'], 'Queued');
      repo.rows = [
        {...contact, 'id': 'created', '_contact': false},
      ];
      repo.pending = [];
      repo.messageLoader = (mode, sent, id) async => {
        'data': [
          {
            'id': 'server-message',
            'client_message_id': 'queued-contact',
            'body': 'Hello',
            'sender_user_id': 'me',
            'sent_at': '2026-01-01T10:00:00Z',
          },
        ],
        'has_more': false,
      };
      await controller.refresh();
      expect(controller.selected?['id'], 'created');
      expect(controller.selected?['_contact'], isFalse);
      expect(controller.messages.length, 1);
      expect(controller.messages.single['_delivery'], 'Sent');
      controller.dispose();
      await repo.dispose();
    },
  );
  test('class filter can find a conversation only on inbox page two', () async {
    final repo = FakeWorkspaceRepository();
    repo.conversationLoader = (monitor, page) async => page == 1
        ? {
            'data': [
              {...thread('one', 'Riya'), 'class_label': 'Nursery A'},
            ],
            'has_more': true,
          }
        : {
            'data': [
              {...thread('two', 'Nisha'), 'class_label': 'LKG B'},
            ],
            'has_more': false,
          };
    final controller = ChatWorkspaceController(repo, 'teacher');
    await controller.start();
    controller.classFilter = 'LKG B';
    controller.updateFilters();
    expect(controller.visibleRows.single['id'], 'two');
    expect(controller.hasMoreInbox, isFalse);
    controller.dispose();
    await repo.dispose();
  });
  testWidgets(
    'phone thread has one back action, composer and no global navigation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeWorkspaceRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatWorkspaceScreen(role: 'teacher', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Riya'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byTooltip('Back to conversations'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-composer')), findsOneWidget);
      expect(find.byTooltip('Back to dashboard'), findsNothing);
      await tester.tap(find.byTooltip('Back to conversations'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repo.dispose();
    },
  );
  testWidgets('wide layout retains inbox and dark mode uses dark surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeWorkspaceRepository();
    repo.rows = repo.rows
        .map((e) => {...e, 'type': 'principal_parent'}..remove('teacher'))
        .toList();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ChatWorkspaceScreen(role: 'principal', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose a conversation'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
    await tester.tap(find.text('Riya'));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-composer')), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final context = tester.element(find.byType(Scaffold).first);
    expect(
      scaffold.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      const Color(0xFF111B28),
    );
    await tester.pumpWidget(const SizedBox());
    await repo.dispose();
  });
  test(
    'profile photos use adult profiles and staff names support first/last',
    () {
      final row = {
        'type': 'principal_parent',
        'parent_id': 'p',
        'parent': {
          'name': 'Riya',
          'avatar_url': 'https://example.test/parent.png',
        },
        'student': {
          'name': 'Aarav',
          'avatar_url': 'https://example.test/child.png',
        },
      };
      expect(chatPhoto(row, 'principal'), 'https://example.test/parent.png');
      expect(
        chatName({
          'teacher': {'first_name': 'Ananya', 'last_name': 'Rao'},
        }, 'parent'),
        'Ananya Rao',
      );
      expect(
        chatPhoto({
          'leader': {'avatar_url': 'https://example.test/leader.png'},
        }, 'parent'),
        'https://example.test/leader.png',
      );
    },
  );
  testWidgets('600px workspace supports enlarged text without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeWorkspaceRepository();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: ChatWorkspaceScreen(role: 'teacher', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Riya'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('chat-composer')),
      'A longer classroom update for the family.',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await repo.dispose();
  });
  if (const bool.fromEnvironment('CHAT_CAPTURE')) {
    setUpAll(() async {
      final text = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
        ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'));
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await Future.wait([text.load(), icons.load()]);
    });
    for (final role in ['parent', 'teacher', 'principal', 'coordinator']) {
      testWidgets('capture rendered $role inbox and thread', (tester) async {
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          await tester.binding.setSurfaceSize(const Size(420, 920));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final repo = FakeWorkspaceRepository();
          if (role == 'principal' || role == 'coordinator') {
            repo.rows = repo.rows
                .map(
                  (e) => {...e, 'type': 'principal_parent'}..remove('teacher'),
                )
                .toList();
          }
          repo.rows = repo.rows
              .map(
                (e) => {
                  ...e,
                  'school_name': 'ArishVille PreSchool',
                  'last_message': 'Thank you for the update.',
                },
              )
              .toList();
          if (role == 'principal' || role == 'coordinator') {
            repo.conversationLoader = (monitor, page) async => {
              'data': monitor
                  ? [thread('one', 'Riya'), thread('two', 'Nisha')]
                  : repo.rows,
              'has_more': false,
            };
          }
          repo.messageLoader = (mode, sent, id) async => {
            'data': [
              {
                'id': 'inbound',
                'body': 'Good morning! Aarav joined circle time today.',
                'sender_user_id': 'other',
                'sender_name': role == 'parent' ? 'Ananya Rao' : 'Riya Sharma',
                'sender_role': role == 'parent' ? 'teacher' : 'parent',
                'sent_at': DateTime.now()
                    .toUtc()
                    .subtract(const Duration(minutes: 3))
                    .toIso8601String(),
              },
              {
                'id': 'outbound',
                'body':
                    'Thank you for the update. We will see you this afternoon.',
                'sender_user_id': 'me',
                'sender_name': 'You',
                'sender_role': role,
                'recipient_read': true,
                'sent_at': DateTime.now().toUtc().toIso8601String(),
              },
            ],
            'has_more': false,
          };
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  brightness: role == 'teacher' || role == 'coordinator'
                      ? Brightness.dark
                      : Brightness.light,
                  fontFamily: 'Inter',
                ),
                home: ChatWorkspaceScreen(role: role, repository: repo),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> capture(String suffix) async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '.local/chat-redesign-20261017/rendered/$role-$suffix.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('inbox');
          await tester.tap(
            find.text(role == 'parent' ? 'Ananya' : 'Riya').first,
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Good morning! Aarav joined circle time today.'),
            findsOneWidget,
          );
          await capture('thread');
          if (role == 'principal' || role == 'coordinator') {
            await tester.tap(find.byTooltip('Back to conversations'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Monitor'));
            await tester.pumpAndSettle();
            await capture('monitor');
            await tester.tap(find.text('Riya ↔ Ananya'));
            await tester.pumpAndSettle();
            await capture('monitor-thread');
          }
          await tester.pumpWidget(const SizedBox());
          await repo.dispose();
        } finally {
          debugDisableShadows = previousShadows;
        }
      });
    }
  }
}
