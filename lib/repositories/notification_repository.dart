import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stored_notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Persists a row in `notifications` for the in-app الإشعارات tab (no server push).
  Future<void> saveNotificationDocument({
    required String title,
    required String body,
  }) async {
    await _firestore.collection('notifications').add(<String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Newest admin announcements for the الإشعارات tab.
  Stream<List<StoredNotification>> watchStoredNotifications({int limit = 100}) {
    return _firestore
        .collection('notifications')
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final Map<String, dynamic> data = d.data();
        return StoredNotification(
          id: d.id,
          title: (data['title'] as String?)?.trim() ?? '',
          body: (data['body'] as String?)?.trim() ?? '',
          sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
        );
      }).toList(growable: false);
    });
  }
}
