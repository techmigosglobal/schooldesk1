import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/modules/profile/domain/profile_repository.dart';
import 'package:schooldesk1/features/profile/presentation/screens/school_profile_screen/school_profile_screen.dart';

class _Profile implements ProfileRepository {
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>> loadCurrentSchool() async => {
    'name': 'Existing branch',
    'display_name': 'ArishVille PreSchool',
    'school_type': 'Preschool',
    'timezone': 'Asia/Kolkata',
    'currency': 'INR',
  };
  @override
  Future<Map<String, dynamic>> updateCurrentSchool(
    Map<String, dynamic> payload,
  ) async {
    saved = payload;
    return payload;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'blank profile fields stay hidden and partial details save without required errors',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      BackendApiClient.instance.setCurrentRole('principal');
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Profile();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: SchoolProfileScreen(repository: repository),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Affiliation Board'), findsNothing);
      expect(find.text('Contact'), findsNothing);
      await tester.tap(find.text('Edit').first);
      await tester.pump();
      expect(find.text('Affiliation Board'), findsOneWidget);
      await tester.tap(find.text('Save').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.saved, isNotNull);
      expect(repository.saved!['display_name'], 'ArishVille PreSchool');
      expect(find.textContaining('is required'), findsNothing);
      expect(find.text('Affiliation Board'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
