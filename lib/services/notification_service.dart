import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../providers/notification_provider.dart';

/// Top-level Firebase messaging background delegate (must stay in isolate root library).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

String? _broadcastDedupeKey(Map<String, dynamic> data) {
  final Object? raw = data['broadcastId'];
  if (raw is! String) {
    return null;
  }
  final String trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

abstract final class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Must match AndroidManifest meta-data channel id & created channel below.
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'Important notifications',
    description: 'تنبيهات نقاط التفتيش',
    importance: Importance.high,
  );

  static int _notificationId = 1;

  static Future<void> initialize(NotificationProvider inbox) async {
    if (!kIsWeb) {
      await _configureLocalNotifications();
      await _requestPermissions();
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final RemoteNotification? n = message.notification;
        final String title = n?.title ??
            message.data['title'] as String? ??
            message.data['gcm.notification.title'] as String? ??
            'تحديث';
        final String body = n?.body ??
            message.data['body'] as String? ??
            message.data['gcm.notification.body'] as String? ??
            '';
        inbox.addForegroundLine(
          title,
          body,
          dedupeKey: _broadcastDedupeKey(message.data),
        );
        await _showForegroundLocalNotification(title, body, message.data);
      });
    }

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (kIsWeb) {
        return;
      }
      if (user == null || user.isAnonymous) {
        return;
      }
      unawaited(_persistTokenForUid(user.uid));
    });

    if (!kIsWeb) {
      _messaging.onTokenRefresh.listen((String token) async {
        final User? u = FirebaseAuth.instance.currentUser;
        if (u != null && !u.isAnonymous && u.uid.isNotEmpty) {
          await _writeFcmToken(u.uid, token);
        }
      });

      await _persistInitialTokenIfSignedIn();

      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? m) {
        if (m == null) {
          return;
        }
        final RemoteNotification? n = m.notification;
        if (n != null) {
          inbox.addForegroundLine(
            n.title ?? 'رسالة مفتوحة',
            n.body ?? '',
            dedupeKey: _broadcastDedupeKey(m.data),
          );
        }
      });
    }
  }

  static Future<void> _configureLocalNotifications() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(_androidChannel);

    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        // Optionally handle tap payloads later.
      },
    );
  }

  static Future<void> _requestPermissions() async {
    final NotificationSettings settings =
        await _messaging.requestPermission(
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    if (kDebugMode &&
        settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
    }

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> _persistInitialTokenIfSignedIn() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        !user.isAnonymous &&
        user.uid.isNotEmpty) {
      await _persistTokenForUid(user.uid);
    }
  }

  static Future<void> _persistTokenForUid(String uid) async {
    try {
      final String? token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _writeFcmToken(uid, token);
      }
    } catch (e, st) {
      debugPrint('[FCM] getToken failed: $e\n$st');
    }
  }

  static Future<void> _writeFcmToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
            <String, dynamic>{'fcmToken': token},
            SetOptions(merge: true),
          );
    } catch (e, st) {
      debugPrint('[FCM] write token to Firestore failed: $e\n$st');
    }
  }

  static Future<void> _showForegroundLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _flutterLocalNotificationsPlugin.show(
      _notificationId++,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }
}
