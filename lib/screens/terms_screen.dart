// lib/screens/terms_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'map_homescreen.dart'; // Import MapScreen so we can go there directly
import 'package:flutter/material.dart';
import 'gradient_background.dart';
import 'read_terms_screen.dart.dart';
// 1. Remove the MapScreen import
// import 'map_homescreen.dart';
// 2. Add the new screen import
import 'add_profile_picture_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _isChecked = false;

  void _openTermsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReadTermsScreen()),
    );
  }

  void _onContinue() async {
    if (!_isChecked) return;

    setState(() {
      // Optional: Show a loading indicator if you want,
      // but for a quick check, blocking interaction is usually enough.
    });

    // 1. Save that they accepted terms
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accepted_terms', true);

    if (!mounted) return;

    // 2. Check if user already has a profile picture
    final user = FirebaseAuth.instance.currentUser;
    bool hasProfilePic = false;

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          final String? url = data?['profilePictureUrl'];
          // Check if URL exists and is not empty
          if (url != null && url.isNotEmpty) {
            hasProfilePic = true;
          }
        }
      } catch (e) {
        print("Error checking profile pic: $e");
        // If error, safer to assume false and let them try to add one,
        // or assume true to avoid annoying them. Let's stick to the flow.
      }
    }

    if (!mounted) return;

    // 3. Decide where to go
    if (hasProfilePic) {
      // User already has a pic -> Go straight to Map
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
    } else {
      // New user or no pic -> Go to Add Picture Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AddProfilePictureScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Your build method is 100% correct, no changes needed here) ...
    return Scaffold(
      backgroundColor: Colors.white,
      body: GradientBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sagada Tour Planner',
                  style: TextStyle(
                    height: 1,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'By checking the box, you have read \n and agreed to our terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color.fromARGB(255, 58, 106, 85),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            _isChecked = value ?? false;
                          });
                        },
                      ),
                      Flexible(
                        child: GestureDetector(
                          onTap: _openTermsDialog,
                          child: const Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'I agree with the ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: 'Terms & Agreements',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isChecked ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 58, 106, 85),
                    foregroundColor: Colors.white, // Text color
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
