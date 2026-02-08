// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kReleaseMode
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'services/notification_service.dart'; // 👈 Import
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'auth_wrapper.dart';
import 'screens/map_homescreen.dart';
import 'package:provider/provider.dart';
import 'providers/itinerary_provider.dart';

// Helper function to create a MaterialColor
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  final swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load Environment Variables (API Keys)
  await dotenv.load(fileName: ".env");

  // 2. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Configure Firestore Settings (Offline Persistence)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 4. Activate App Check
  await FirebaseAppCheck.instance.activate(
    // Use ReCaptcha Enterprise or v3 for Web
    webProvider:
        ReCaptchaV3Provider('6Ldm6forAAAAAPCutYaWnsQI8x5KM2ZGUCOfB39J'),

    // Automatically switch providers based on build mode
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity // Release = Secure
        : AndroidProvider.debug, // Debug = Easy testing

    appleProvider: kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
  );

  // (Optional) Set preferred orientations if needed
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ⭐️ 1. Initialize Notification Service
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => ItineraryProvider()..loadActiveItinerary()),
        // You can add other providers here later (e.g. AuthProvider)
      ],
      child: const SagadaTourPlannerApp(),
    ),
  );
}

class SagadaTourPlannerApp extends StatefulWidget {
  const SagadaTourPlannerApp({super.key});

  @override
  State<SagadaTourPlannerApp> createState() => _SagadaTourPlannerAppState();
}

class _SagadaTourPlannerAppState extends State<SagadaTourPlannerApp> {
  @override
  void initState() {
    super.initState();
    // ⭐️ 2. Start Listening for Updates
    _listenForUpdates();
  }

  void _listenForUpdates() {
    // Listen for NEW News
    FirebaseFirestore.instance
        .collection('news')
        .orderBy('postedAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final Timestamp postedAt = data['postedAt'];

        // Check if this is actually new (compare with stored timestamp)
        final prefs = await SharedPreferences.getInstance();
        final lastSeen = prefs.getInt('last_news_timestamp') ?? 0;

        if (postedAt.millisecondsSinceEpoch > lastSeen) {
          // It's new! Show notification
          NotificationService().showNotification(
            id: doc.id.hashCode,
            title: "News Update: ${data['title']}",
            body: data['body'] ?? "Check the app for the latest news.",
          );
          // Update local storage
          await prefs.setInt(
              'last_news_timestamp', postedAt.millisecondsSinceEpoch);
        }
      }
    });

    // Listen for NEW Road Closures
    FirebaseFirestore.instance
        .collection('roadClosures')
        .snapshots()
        .listen((snapshot) async {
      // Simple check: if the count increases, something was added.
      // For a more robust check, you can add a 'createdAt' field to closures.
      // Here is a basic implementation assuming you just want to alert on change:
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          // Only notify if it looks like a real alert
          NotificationService().showNotification(
            id: change.doc.id.hashCode,
            title: "Road Closure Alert",
            body:
                "New advisory for ${data['location'] ?? 'Sagada'}. Check map for details.",
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... existing MaterialApp code ...
      // Just wrap your existing MaterialApp here or copy the contents of your old build method
      title: 'Sagada Tour Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        primarySwatch: createMaterialColor(const Color(0xFF3A6A55)),
        primaryColor: const Color(0xFF3A6A55),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/terms': (context) => const TermsAgreementScreen(),
        '/home': (context) => const AuthWrapper(),
        '/map_home': (context) => const MapScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}
