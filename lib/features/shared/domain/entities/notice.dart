/// Notice / Circular entity.
class Notice {
  final String id;
  final String title;
  final String content;
  final String
  type; // 'General', 'Holiday', 'Emergency', 'Event', 'Fee', 'Exam'
  final String targetAudience; // 'All', 'Teachers', 'Parents', 'Students'
  final String publishedBy;
  final String publishedByRole;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final bool isUrgent;
  final bool isPublished;
  final List<String> readBy;

  const Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.targetAudience,
    required this.publishedBy,
    required this.publishedByRole,
    required this.publishedAt,
    this.expiresAt,
    this.isUrgent = false,
    this.isPublished = true,
    this.readBy = const [],
  });

  bool isReadBy(String userId) => readBy.contains(userId);

  Notice copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    String? targetAudience,
    String? publishedBy,
    String? publishedByRole,
    DateTime? publishedAt,
    DateTime? expiresAt,
    bool? isUrgent,
    bool? isPublished,
    List<String>? readBy,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      targetAudience: targetAudience ?? this.targetAudience,
      publishedBy: publishedBy ?? this.publishedBy,
      publishedByRole: publishedByRole ?? this.publishedByRole,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUrgent: isUrgent ?? this.isUrgent,
      isPublished: isPublished ?? this.isPublished,
      readBy: readBy ?? this.readBy,
    );
  }

  @override
  bool operator ==(Object other) => other is Notice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
