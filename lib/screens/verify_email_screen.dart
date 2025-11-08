// lib/screens/verify_email_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'gradient_background.dart';
import 'email_verified_screen.dart'; // Your success screen

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    canResendEmail = false;
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => canResendEmail = true);
      }
    });

    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkEmailVerified(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      setState(() => canResendEmail = false);
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Verification email sent."),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(seconds: 10));
      if (mounted) setState(() => canResendEmail = true);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Failed to send verification email: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => canResendEmail = true);
      }
    }
  }

  Future<void> _checkEmailVerified() async {
    final navigator = Navigator.of(context);
    final user = FirebaseAuth.instance.currentUser;

    await user?.reload();

    if (user != null && user.emailVerified) {
      setState(() => isEmailVerified = true);
      timer?.cancel(); // Stop the timer

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isVerified': true},
      );

      // --- ⭐️ THIS IS THE FIX ⭐️ ---

      // 1. DO NOT SIGN OUT. This was the original bug.
      // await FirebaseAuth.instance.signOut(); // <-- THIS LINE REMAINS DELETED

      if (!mounted) return;

      // 2. Go to the EmailVerifiedScreen (your success screen)
      //    This is what you wanted.
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const EmailVerifiedScreen()),
      );
      // --- ⭐️ END OF FIX ⭐️ ---
    }
  }

  @override
  Widget build(BuildContext context) {
    // No changes needed in the build method.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.jpg', width: 80, height: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Sagada Tour Planner',
                    style: TextStyle(
                      height: 1,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 60),
                  const Text(
                    'Check Your Email',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'A verification email has been sent to:\n${widget.email}\n\nPlease check your inbox (and spam folder).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 58, 106, 85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: canResendEmail ? _sendVerificationEmail : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 58, 106, 85),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      canResendEmail ? 'Resend Email' : 'Wait to Resend',
                      style: const TextStyle(fontSize: 16),
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
