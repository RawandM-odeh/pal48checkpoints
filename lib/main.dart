import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/checkpoint_provider.dart';
import 'providers/notification_provider.dart';
import 'repositories/checkpoint_repository.dart';
import 'repositories/notification_repository.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user/user_screen.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final NotificationProvider notificationProvider = NotificationProvider();

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  await NotificationService.initialize(notificationProvider);

  runApp(
    MultiProvider(
      providers: [
        Provider<CheckpointRepository>(
          create: (_) => CheckpointRepository(),
        ),
        Provider<NotificationRepository>(
          create: (_) => NotificationRepository(),
        ),
        ChangeNotifierProvider<NotificationProvider>.value(
          value: notificationProvider,
        ),
        ChangeNotifierProvider<CheckpointProvider>(
          create: (BuildContext context) => CheckpointProvider(
            context.read<CheckpointRepository>(),
          ),
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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D9488),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF0D9488),
      ),
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        return FutureBuilder<String>(
          future: FirestoreService().getOrCreateUserRole(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
          ),
          builder: (BuildContext context, AsyncSnapshot<String> roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
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
      },
    );
  }
}
