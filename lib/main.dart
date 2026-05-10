import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/checkpoint_provider.dart';
import 'providers/favorite_checkpoints_provider.dart';
import 'providers/guest_browse_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/user_location_provider.dart';
import 'repositories/checkpoint_repository.dart';
import 'repositories/notification_repository.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user/user_screen.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final NotificationProvider notificationProvider = NotificationProvider();

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  await NotificationService.initialize(notificationProvider);

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        Provider<CheckpointRepository>(create: (_) => CheckpointRepository()),
        Provider<NotificationRepository>(
          create: (_) => NotificationRepository(),
        ),
        ChangeNotifierProvider<NotificationProvider>.value(
          value: notificationProvider,
        ),
        ChangeNotifierProvider<CheckpointProvider>(
          create: (BuildContext context) =>
              CheckpointProvider(context.read<CheckpointRepository>()),
        ),
        ChangeNotifierProvider<UserLocationProvider>(
          create: (_) => UserLocationProvider(),
        ),
        ChangeNotifierProvider<GuestBrowseProvider>(
          create: (_) => GuestBrowseProvider(prefs),
        ),
        ChangeNotifierProvider<FavoriteCheckpointsProvider>(
          create: (_) => FavoriteCheckpointsProvider(prefs, FirestoreService()),
        ),
      ],
      child: const CheckpointAppRoot(),
    ),
  );
}

class CheckpointAppRoot extends StatelessWidget {
  const CheckpointAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق نقاط التفتيش',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: CheckpointTheme.light(),
      darkTheme: CheckpointTheme.dark(),
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GuestBrowseProvider>(
      builder: (BuildContext context, GuestBrowseProvider guest, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (BuildContext context, AsyncSnapshot<User?> authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final User? firebaseUser = authSnapshot.data;
            if (firebaseUser != null) {
              if (!firebaseUser.isAnonymous && guest.isGuestBrowsing) {
                guest.scheduleExitGuestIfStale();
              }
              if (firebaseUser.isAnonymous) {
                return const UserScreen();
              }
              return FutureBuilder<String>(
                future: FirestoreService().getOrCreateUserRole(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? '',
                ),
                builder:
                    (BuildContext context, AsyncSnapshot<String> roleSnapshot) {
                      if (roleSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final String role = roleSnapshot.data ?? 'user';
                      if (role == 'admin') {
                        return const AdminScreen();
                      }
                      return const UserScreen();
                    },
              );
            }

            if (guest.isGuestBrowsing) {
              return const UserScreen();
            }

            return const LoginScreen();
          },
        );
      },
    );
  }
}
