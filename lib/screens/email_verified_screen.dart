import 'dart:async'; // Import this for the Timer
import 'package:flutter/material.dart';
import 'gradient_background.dart';
// Import the TermsAgreementScreen
import 'terms_screen.dart';

// 1. Convert to StatefulWidget
class EmailVerifiedScreen extends StatefulWidget {
  const EmailVerifiedScreen({super.key});

  @override
  State<EmailVerifiedScreen> createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends State<EmailVerifiedScreen> {
  Timer? _timer;
  int _countdown = 5; // Timer duration in seconds

  @override
  void initState() {
    super.initState();
    // Start the timer when the screen loads
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        if (mounted) {
          setState(() => _countdown--);
        }
      } else {
        // When countdown hits 0, redirect
        _redirect();
      }
    });
  }

  void _redirect() {
    if (!mounted) return;
    _timer?.cancel(); // Stop the timer so it doesn't fire again

    // Navigate to your app's main screen (TermsAgreementScreen)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TermsAgreementScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel(); // Always cancel the timer when the screen is closed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5.0),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 80,
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sagada Tour Planner and Map',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/images/check.png',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 15),

                  // Title
                  const Text(
                    "Congratulations!\nYou’ve finished\ncreating an\naccount.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 2. MODIFIED MESSAGE ---
                  Text(
                    "Redirecting you in $_countdown seconds...",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color.fromARGB(255, 58, 106, 85),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 3. MODIFIED BUTTON ---
                  ElevatedButton(
                    onPressed: _redirect, // Call the redirect function
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 58, 106, 85),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Continue Now", // Changed text
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
