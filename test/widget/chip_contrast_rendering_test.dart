import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} rendered chips resolve every state color',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.physicalSize = const Size(360, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                body: SafeArea(
                  child: DefaultTextStyle(
                    style: TextStyle(color: dark ? Colors.black : Colors.white),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: true,
                          onSelected: (_) {},
                        ),
                        ChoiceChip(
                          label: const Text('Teachers'),
                          selected: false,
                          onSelected: (_) {},
                        ),
                        const ChoiceChip(
                          label: Text('Disabled choice'),
                          selected: true,
                        ),
                        FilterChip(
                          label: const Text('Parents'),
                          selected: true,
                          onSelected: (_) {},
                        ),
                        FilterChip(
                          label: const Text('Unread'),
                          selected: false,
                          onSelected: (_) {},
                        ),
                        const FilterChip(
                          label: Text('Disabled filter'),
                          selected: true,
                          onSelected: null,
                        ),
                        ActionChip(
                          label: const Text('All classes'),
                          focusNode: focus,
                          onPressed: () {},
                        ),
                        const ActionChip(label: Text('Disabled action')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        for (final entry in {
          'All': theme.chipTheme.selectedColor!,
          'Teachers': theme.chipTheme.backgroundColor!,
          'Disabled choice': theme.chipTheme.disabledColor!,
          'Parents': theme.chipTheme.selectedColor!,
          'Unread': theme.chipTheme.backgroundColor!,
          'Disabled filter': theme.chipTheme.disabledColor!,
          'All classes': theme.chipTheme.backgroundColor!,
          'Disabled action': theme.chipTheme.disabledColor!,
        }.entries) {
          final foreground = DefaultTextStyle.of(
            tester.element(find.text(entry.key)),
          ).style.color!;
          final a = foreground.computeLuminance(),
              b = entry.value.computeLuminance();
          final contrast = ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
          expect(contrast, greaterThanOrEqualTo(4.5), reason: entry.key);
        }
        expect(tester.takeException(), isNull);
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final screenshot = await boundary.toImage();
          final bytes = await screenshot.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final folder = Directory('/tmp/schooldesk-feed-evidence')
            ..createSync(recursive: true);
          File(
            '${folder.path}/chips-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          screenshot.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
