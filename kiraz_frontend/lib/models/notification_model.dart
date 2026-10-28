class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String? type;
  final int? referenceId;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type,
    this.referenceId,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['createdAt'] != null) {
      try {
        parsedDate = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }

    int? refId;
    if (json['referenceId'] != null) {
      refId = json['referenceId'] is int
          ? json['referenceId'] as int
          : int.tryParse(json['referenceId'].toString());
    }

    return AppNotification(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse(json['userId'].toString()) ?? 0,
      title: (json['title'] ?? '') as String,
      message: (json['message'] ?? '') as String,
      type: json['type']?.toString(),
      referenceId: refId,
      isRead: json['isRead'] == true || json['read'] == true,
      createdAt: parsedDate,
    );
  }
}
