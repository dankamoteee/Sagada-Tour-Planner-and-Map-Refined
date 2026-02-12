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

import 'models/event_model.dart';
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
  // Capture the exact time the app started
  final DateTime _appStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _listenForUpdates();
    // Schedule reminders for the current active itinerary
    _scheduleItineraryReminders();
  }

  void _listenForUpdates() {
    // 1. REFINED NEWS LISTENER
    FirebaseFirestore.instance
        .collection('news')
        .orderBy('postedAt', descending: true)
        .limit(5) // Increase limit to catch multiple updates
        .snapshots()
        .listen((snapshot) async {
      final prefs = await SharedPreferences.getInstance();
      // Default to now if first run, so we don't blast old news
      final lastSeenTime = prefs.getInt('last_news_timestamp') ??
          DateTime.now().millisecondsSinceEpoch;
      int maxTimestamp = lastSeenTime;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final Timestamp? postedAt =
              data['postedAt']; // Use nullable to be safe

          if (postedAt != null) {
            final int msgTime = postedAt.millisecondsSinceEpoch;

            // Only notify if this specific article is newer than what we've seen
            if (msgTime > lastSeenTime) {
              NotificationService().showNotification(
                id: change.doc.id.hashCode,
                title: "News Update: ${data['title']}",
                body: data['body'] ?? "Tap to read more.",
              );

              // Keep track of the newest timestamp found
              if (msgTime > maxTimestamp) {
                maxTimestamp = msgTime;
              }
            }
          }
        }
      }

      // Update storage with the newest timestamp found
      await prefs.setInt('last_news_timestamp', maxTimestamp);
    });

    // 2. REFINED ROAD CLOSURE LISTENER
    FirebaseFirestore.instance
        .collection('roadClosures')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;

          // CRITICAL FIX: Check if the document has a timestamp.
          // If you don't have a 'createdAt' field, you can use a fallback mechanism,
          // but adding the field is highly recommended.
          Timestamp? createdAt = data['createdAt'];
          // Use 'postedAt' or whatever timestamp field you use.
          // If null, we skip notification to avoid startup spam.

          if (createdAt != null) {
            DateTime closureTime = createdAt.toDate();

            // Only notify if the closure was reported AFTER the app started running
            // This prevents "Old" closures from popping up on launch.
            if (closureTime.isAfter(_appStartTime)) {
              NotificationService().showNotification(
                id: change.doc.id.hashCode,
                title: "Road Closure Alert",
                body:
                    "New advisory for ${data['location'] ?? 'Sagada'}. Tap to view.",
              );
            }
          }
        }
      }
    });
  }

  // 3. NEW: SCHEDULE ITINERARY REMINDERS
  void _scheduleItineraryReminders() async {
    // 1. Wait for the widget to be ready
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // 2. Get the Active ID from the provider
    final itineraryProvider =
        Provider.of<ItineraryProvider>(context, listen: false);
    final String? itineraryId = itineraryProvider.activeItineraryId;

    // 3. If we have an active trip, fetch its events from Firestore
    if (itineraryId != null) {
      try {
        // NOTE: Adjust the path below if your events are stored differently.
        // I am assuming a structure of: itineraries -> [ID] -> events (subcollection)
        final QuerySnapshot eventSnapshot = await FirebaseFirestore.instance
            .collection('itineraries')
            .doc(itineraryId)
            .collection('events')
            .get();

        for (var doc in eventSnapshot.docs) {
          // Convert Firestore data to your Event model
          final event = CalendarEvent.fromFirestore(doc);

          // 4. Schedule the notification
          // (NotificationService handles the logic to ignore past events)
          NotificationService().scheduleEventNotification(
            id: event.id.hashCode, // Unique ID for the notification
            title: event.title,
            body: "Happening soon at ${event.location}",
            scheduledTime: event.date,
          );
        }
        print("Scheduled reminders for ${eventSnapshot.docs.length} events.");
      } catch (e) {
        print("Error scheduling reminders: $e");
      }
    }
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
