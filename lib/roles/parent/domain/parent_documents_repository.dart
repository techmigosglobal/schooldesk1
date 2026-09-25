import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';

abstract interface class ParentDocumentsRepository {
  Future<Result<List<Map<String, dynamic>>>> loadChildren({
    required int refreshNonce,
  });

  Future<Result<Map<String, dynamic>>> loadSchool();

  Future<Result<UserResponse>> loadProfile();

  Future<Result<List<Map<String, dynamic>>>> loadStudentDocuments(
    String studentId,
  );

  Future<Result<void>> deleteStudentDocument(String documentId);

  Future<Result<String>> uploadDocument(
    String path, {
    required String filename,
  });

  Future<Result<void>> createStudentDocument({
    required String type,
    required String title,
    required String fileUrl,
    required String studentId,
  });
}
