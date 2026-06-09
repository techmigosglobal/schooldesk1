import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Class Hub CSV import uses backend dry-run before import', () {
    final importer = File(
      'lib/core/services/bulk_csv_import_service.dart',
    ).readAsStringSync();
    final principalApi = File(
      'lib/core/network/api_modules/principal_api.dart',
    ).readAsStringSync();
    final routes = File(
      'school-backend/internal/routes/principal_routes.go',
    ).readAsStringSync();
    final handler = File(
      'school-backend/internal/handlers/principal_classes_import.go',
    ).readAsStringSync();

    expect(principalApi, contains('dryRunPrincipalClassCsvImport'));
    expect(principalApi, contains('/principal/classes/import/dry-run'));
    expect(principalApi, contains('importPrincipalClassCsv'));
    expect(principalApi, contains('/principal/classes/import'));

    expect(importer, contains('_showClassHubDryRunDialog'));
    expect(importer, contains('dryRunPrincipalClassCsvImport'));
    expect(importer, contains('importPrincipalClassCsv'));
    expect(
      importer.indexOf('dryRunPrincipalClassCsvImport'),
      lessThan(importer.indexOf('importPrincipalClassCsv')),
    );

    expect(routes, contains('/classes/import/dry-run'));
    expect(routes, contains('/classes/import'));
    expect(handler, contains('database.DB.Transaction'));
    expect(handler, contains('CSV_IMPORT_VALIDATION_FAILED'));
    expect(handler, contains('existing class section will be updated'));
    expect(handler, contains('"room_number"'));
    expect(handler, contains('classImportRoomFields'));
    expect(handler, contains('will be created if missing'));
    expect(principalApi, contains("'room_number': roomNumber.trim()"));
  });
}
