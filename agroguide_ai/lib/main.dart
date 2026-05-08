import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/notification_storage.dart';
import 'services/database_service.dart';
import 'models/notification_model.dart';
import 'providers/settings_provider.dart';
import 'features/ai_expert/services/ai_expert_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Storage early
  final storage = NotificationStorage();
  try {
    await storage.init();
    
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? 'dummy_key',
        appId: dotenv.env['FIREBASE_APP_ID'] ?? 'dummy_app_id',
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? 'dummy_sender',
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? 'dummy_project',
      ),
    );
  } catch (e) {
    debugPrint("Init error: $e");
  }

  // Initialize notifications & permissions
  final notificationService = NotificationService(storage: storage);
  await notificationService.init();

  runApp(CroporaApp(notificationService: notificationService, storage: storage));
}

class CroporaApp extends StatelessWidget {
  final NotificationService notificationService;
  final NotificationStorage storage;
  
  CroporaApp({
    super.key, 
    required this.notificationService,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        Provider(create: (_) => ApiService()),
        Provider.value(value: storage),
        Provider.value(value: notificationService),
        Provider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => AiExpertService()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Cropora AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'), Locale('hi'), Locale('te'), Locale('ta'),
              Locale('kn'), Locale('ml'), Locale('pa'), Locale('mr'),
              Locale('gu'), Locale('bn'), Locale('or'), Locale('as'),
              Locale('ur'),
            ],
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}
