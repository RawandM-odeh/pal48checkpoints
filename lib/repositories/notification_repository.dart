import 'package:cloud_functions/cloud_functions.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

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
