import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

void main() {
  Future<List<FlutterErrorDetails>> pumpAt(
    WidgetTester tester, {
    required Size size,
    required double textScale,
  }) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Column(
              children: [
                const Expanded(
                  child: ChatBubbleWidget(
                    messageText:
                        'A long message with class and student context should wrap without overflowing the chat pane.',
                    time: '10:30 AM',
                    isMe: false,
                    isRead: true,
                    senderLabel: 'Principal with a long display name',
                    senderRoleLabel: 'Coordinator',
                  ),
                ),
                ChatInputBar(
                  controller: _NoopController.controller,
                  onSend: _NoopController.send,
                  placeholder: 'Reply to this conversation',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    FlutterError.onError = previous;
    await tester.binding.setSurfaceSize(null);
    return errors;
  }

  testWidgets('chat widgets remain stable on compact phones', (tester) async {
    final errors = await pumpAt(
      tester,
      size: const Size(320, 720),
      textScale: 1.0,
    );
    expect(errors.where((error) => error.exception is FlutterError), isEmpty);
    expect(find.byType(ChatBubbleWidget), findsOneWidget);
    expect(find.byTooltip('Send message'), findsOneWidget);
  });

  testWidgets('chat widgets remain stable with large text on tablet', (tester) async {
    final errors = await pumpAt(
      tester,
      size: const Size(768, 1024),
      textScale: 1.6,
    );
    expect(errors.where((error) => error.exception is FlutterError), isEmpty);
  });
}

class _NoopController {
  static final controller = TextEditingController();
  static void send() {}
}
