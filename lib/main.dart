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
import 'package:firebase_auth/firebase_auth.dart';

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    _listenForUpdates();
    _configureSelectNotificationSubject();

    // ⭐️ FIX: Wait for the app frame to build so Provider is accessible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ItineraryProvider>(context, listen: false);

      // 1. Schedule immediately if it loaded fast enough
      if (provider.activeItineraryId != null) {
        _scheduleItineraryReminders();
      }

      // 2. Listen for whenever the user changes their active itinerary later!
      provider.addListener(() {
        // If the ID isn't null, schedule the reminders for the new trip
        if (provider.activeItineraryId != null) {
          _scheduleItineraryReminders();
        }
      });
    });
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
        .listen((snapshot) async {
      // 👈 Make async

      final prefs = await SharedPreferences.getInstance();
      // Default to app start time if first run
      final lastClosureTime = prefs.getInt('last_closure_timestamp') ??
          DateTime.now().millisecondsSinceEpoch;
      int maxTimestamp = lastClosureTime;

      for (var change in snapshot.docChanges) {
        // Only care if added or modified
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>;
          final Timestamp? createdAt =
              data['createdAt']; // Ensure this field exists!

          if (createdAt != null) {
            final int closureMsgTime = createdAt.millisecondsSinceEpoch;

            // ⭐️ CHECK: Is this closure actually new?
            if (closureMsgTime > lastClosureTime) {
              NotificationService().showNotification(
                id: change.doc.id.hashCode,
                title: change.type == DocumentChangeType.added
                    ? "New Road Closure"
                    : "Road Closure Update",
                body: "Advisory for ${data['location'] ?? 'Sagada'}.",
                payload: 'road_closures', // 👈 Add payload for redirection
              );

              // Update max timestamp found
              if (closureMsgTime > maxTimestamp) {
                maxTimestamp = closureMsgTime;
              }
            }
          }
        }
      }

      // Save the new latest time
      if (maxTimestamp > lastClosureTime) {
        await prefs.setInt('last_closure_timestamp', maxTimestamp);
      }
    });
  }

  // 3. NEW: SCHEDULE ITINERARY REMINDERS
  void _scheduleItineraryReminders() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // ⭐️ FIX 1: Get the current logged-in user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Exit if no one is logged in

    await NotificationService().cancelAllScheduledNotifications();

    final itineraryProvider =
        Provider.of<ItineraryProvider>(context, listen: false);
    final String? itineraryId = itineraryProvider.activeItineraryId;

    if (itineraryId != null) {
      try {
        // ⭐️ FIX 2: Corrected the Firestore path to include 'users' and 'user.uid'
        final QuerySnapshot eventSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('itineraries')
            .doc(itineraryId)
            .collection('events')
            .get();

        for (var doc in eventSnapshot.docs) {
          final event = CalendarEvent.fromFirestore(doc);

          NotificationService().scheduleEventNotification(
            id: event.id.hashCode,
            title: event.title,
            body: "Happening soon at ${event.location}",
            scheduledTime: event.date,
          );
        }
        // This print statement will now show up in your debug console to prove it worked!
        print("Scheduled reminders for ${eventSnapshot.docs.length} events.");
      } catch (e) {
        print("Error scheduling reminders: $e");
      }
    }
  }

  // ⭐️ NEW: Listen for notification clicks
  void _configureSelectNotificationSubject() {
    NotificationService()
        .selectNotificationStream
        .stream
        .listen((String? payload) {
      if (payload != null && navigatorKey.currentState != null) {
        if (payload == 'road_closures') {
          navigatorKey.currentState!.pushNamed('/map_home');
        } else if (payload == 'news') {
          navigatorKey.currentState!.pushNamed('/home');
        } else if (payload == 'itinerary') {
          // ⭐️ ADD THIS: Route them to their trips when they tap an event reminder
          navigatorKey.currentState!.pushNamed(
              '/home'); // Adjust if your trips tab is a different route
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
