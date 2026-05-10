/// Row from Firestore `notifications` for in-app history.
class StoredNotification {
  const StoredNotification({
    required this.id,
    required this.title,
    required this.body,
    this.sentAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? sentAt;
}
