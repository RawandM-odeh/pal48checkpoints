import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NotificationRepository {
  NotificationRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Persists a row in `notifications` for history / downstream triggers.
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

  /// Calls Cloud Function `sendBroadcastNotification`. Admin-only (enforced server-side).
  Future<void> sendBroadcastToAllUsers({
    required String title,
    required String body,
  }) async {
    final HttpsCallable callable =
        _functions.httpsCallable('sendBroadcastNotification');
    await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
    });
  }
}
