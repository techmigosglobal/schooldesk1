/// Typed view data shared by the mobile chat screens.
///
/// The API intentionally remains map-compatible for older deployments, while
/// these small value objects keep class and student context together at the
/// UI boundary.
class ChatContext {
  final String studentId;
  final String studentName;
  final String sectionId;
  final String classLabel;

  const ChatContext({
    this.studentId = '',
    this.studentName = '',
    this.sectionId = '',
    this.classLabel = '',
  });

  factory ChatContext.fromMap(Map<String, dynamic> row) => ChatContext(
    studentId: chatText(row['student_id']),
    studentName: chatText(
      row['student_name'] ?? _nested(row['student'])?['name'],
    ),
    sectionId: chatText(row['section_id']),
    classLabel: chatText(row['class_label']),
  );

  String get displayLabel =>
      [classLabel, studentName].where((value) => value.isNotEmpty).join(' - ');

  String get shortLabel => classLabel.isNotEmpty ? classLabel : studentName;
}

class ChatContact {
  final String id;
  final String name;
  final String role;
  final String type;
  final String contactRole;
  final ChatContext context;

  const ChatContact({
    required this.id,
    required this.name,
    required this.role,
    required this.type,
    required this.contactRole,
    required this.context,
  });

  factory ChatContact.fromMap(Map<String, dynamic> row) => ChatContact(
    id: chatText(row['id']),
    name: chatText(row['name'], fallback: 'Contact'),
    role: chatText(row['role']).toLowerCase(),
    type: chatText(row['type'], fallback: 'parent_teacher'),
    contactRole: chatText(row['contact_role']),
    context: ChatContext.fromMap(row),
  );
}

class ChatConversation {
  final String id;
  final String type;
  final String teacherId;
  final String parentId;
  final String leaderId;
  final ChatContext context;
  final bool placeholder;

  const ChatConversation({
    required this.id,
    required this.type,
    required this.teacherId,
    required this.parentId,
    required this.leaderId,
    required this.context,
    this.placeholder = false,
  });

  factory ChatConversation.fromMap(Map<String, dynamic> row) =>
      ChatConversation(
        id: chatText(row['id']),
        type: chatText(row['type'], fallback: 'parent_teacher'),
        teacherId: chatText(row['teacher_id']),
        parentId: chatText(row['parent_id']),
        leaderId: chatText(row['leader_id'] ?? row['created_by']),
        context: ChatContext.fromMap(row),
        placeholder: row['is_contact_placeholder'] == true,
      );
}

Map<String, dynamic> normalizeChatContextMap(Map<String, dynamic> row) {
  final context = ChatContext.fromMap(row);
  return {
    ...row,
    'student_id': context.studentId,
    'student_name': context.studentName,
    'section_id': context.sectionId,
    'class_label': context.classLabel,
  };
}

String chatConversationKey(Map<String, dynamic> row) {
  final type = chatText(row['type'], fallback: 'parent_teacher');
  final teacherId = chatText(row['teacher_id']);
  final parentId = chatText(row['parent_id']);
  final studentId = chatText(row['student_id']);
  final leaderId = chatText(row['leader_id'] ?? row['created_by']);
  return '$type|$teacherId|$parentId|$studentId|$leaderId';
}

String chatText(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

Map<String, dynamic>? _nested(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}
