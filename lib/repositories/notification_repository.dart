import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/stored_notification.dart';

class NotificationRepository {
  NotificationRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Persists a row in `notifications` for history / inbox. Returns document id for FCM dedupe.
  Future<String> saveNotificationDocument({
    required String title,
    required String body,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        await _firestore.collection('notifications').add(<String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'sentAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Newest admin broadcasts for the الإشعارات tab.
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

  /// Calls Cloud Function `sendBroadcastNotification`. Admin-only (enforced server-side).
  Future<Map<String, dynamic>> sendBroadcastToAllUsers({
    required String title,
    required String body,
    String? broadcastId,
  }) async {
    final HttpsCallable callable =
        _functions.httpsCallable('sendBroadcastNotification');
    final HttpsCallableResult<Object?> result =
        await callable.call(<String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      if (broadcastId != null && broadcastId.trim().isNotEmpty)
        'broadcastId': broadcastId.trim(),
    });
    final Object? raw = result.data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw as Map<Object?, Object?>);
    }
    return <String, dynamic>{};
  }
}
