import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/constants/storage_keys.dart';

class ParentChildSelectionService {
  ParentChildSelectionService._();

  static Future<int> indexFor(
    List<Map<String, dynamic>> children, {
    int fallback = 0,
  }) async {
    if (children.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getString(StorageKeys.parentSelectedChild) ?? '';
    final index = children.indexWhere((child) => _childId(child) == selectedId);
    if (index >= 0) return index;
    return fallback >= 0 && fallback < children.length ? fallback : 0;
  }

  static Future<void> saveIndex(
    List<Map<String, dynamic>> children,
    int index,
  ) async {
    if (index < 0 || index >= children.length) return;
    final id = _childId(children[index]);
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.parentSelectedChild, id);
  }

  static String _childId(Map<String, dynamic> child) =>
      '${child['id'] ?? child['student_id'] ?? ''}'.trim();
}
