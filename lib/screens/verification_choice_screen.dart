import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_verified_screen.dart';
import 'gradient_background.dart';
import 'verify_email_screen.dart';
import 'verify_otp_screen.dart'; // You will create this file next

class VerificationChoiceScreen extends StatefulWidget {
  final String email;
  final String phone;

  const VerificationChoiceScreen({
    super.key,
    required this.email,
    required this.phone,
  });

  @override
  State<VerificationChoiceScreen> createState() =>
      _VerificationChoiceScreenState();
}

class _VerificationChoiceScreenState extends State<VerificationChoiceScreen> {
  bool _isSendingEmail = false;
  bool _isSendingOTP = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Function for Email Verification ---
  Future<void> _sendEmailVerification() async {
    setState(() => _isSendingEmail = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // --- THIS IS THE FIX ---
      User? user = _auth.currentUser;
      if (user == null) {
        // Wait up to 5 seconds for the auth state to restore
        await for (var authUser in _auth.authStateChanges().timeout(
              const Duration(seconds: 5),
            )) {
          if (authUser != null) {
            user = authUser;
            break; // We found the user, stop listening
          }
        }
      }

      // If user is *still* null, then throw the error
      if (user == null) {
        throw Exception(
          "User session expired. Please restart the app and try again.",
        );
      }
      // --- END OF FIX ---

      await user.sendEmailVerification();

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Verification email sent.'),
          backgroundColor: Colors.green,
        ),
      );

      navigator.push(
        MaterialPageRoute(
          builder: (context) => VerifyEmailScreen(email: widget.email),
        ),
      );
    } on TimeoutException {
      // Handle the case where the user never re-loads
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Could not find user session. Please restart the app."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingEmail = false);
      }
    }
  }

  // --- ADD THIS HELPER METHOD ---
  // This is the logic from VerifyOTPScreen, adapted for this screen
  Future<void> _linkCredential(PhoneAuthCredential credential) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSendingOTP = true); // Keep loading state

    try {
      // 1. Get the user (with the same timeout logic)
      User? user = _auth.currentUser;
      if (user == null) {
        await for (var authUser in _auth.authStateChanges().timeout(
              const Duration(seconds: 5),
            )) {
          if (authUser != null) {
            user = authUser;
            break;
          }
        }
      }
      if (user == null) {
        throw Exception("User session expired. Please restart the app.");
      }

      // 2. Link the credential
      await user.linkWithCredential(credential);

      if (!mounted) return;

      // 3. Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isVerified': true},
      );

      if (!mounted) return;

      // 4. Navigate to success
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const EmailVerifiedScreen(), // Your success screen
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'credential-already-in-use') {
        message = 'This phone number is already linked to another account.';
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } on TimeoutException {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Could not find user session. Please restart the app."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingOTP = false);
      }
    }
  }

  Future<void> _sendPhoneVerification() async {
    setState(() => _isSendingOTP = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    //await _auth.setSettings(appVerificationDisabledForTesting: true);
    await _auth.verifyPhoneNumber(
      phoneNumber: widget.phone,
      verificationCompleted: (PhoneAuthCredential credential) {
        // --- THIS IS THE FIX ---
        // Auto-retrieval successful! Call our new link method.
        if (mounted) {
          _linkCredential(credential);
        }
        // --- END OF FIX ---
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isSendingOTP = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Phone verification failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        // --- THIS IS THE FIX ---
        // We have the ID! NOW we navigate.
        if (!mounted) return;
        setState(() => _isSendingOTP = false);

        navigator.push(
          MaterialPageRoute(
            builder: (context) => VerifyOTPScreen(
              phoneNumber: widget.phone,
              verificationId:
                  verificationId, // <-- This provides the required argument
              resendToken: resendToken,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // You can ignore this for now
      },
    );
  }

  // --- Function for Phone Verification ---

  @override
  Widget build(BuildContext context) {
    // Check if either button is loading to disable both
    final isLoading = _isSendingEmail || _isSendingOTP;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/logo.jpg',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sagada Tour Planner',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 60),
                    const Text(
                      'Verify Your Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please choose a method to verify your account registered with:\n\nEmail: ${widget.email}\nPhone: ${widget.phone}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- Email Button ---
                    ElevatedButton.icon(
                      icon: const Icon(Icons.email_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          58,
                          106,
                          85,
                        ), // Your app's green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Disable if any button is loading
                      onPressed: isLoading ? null : _sendEmailVerification,
                      label: _isSendingEmail
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text('Verify with Email'),
                    ),

                    const SizedBox(height: 16),

                    // --- Phone Button ---
                    ElevatedButton.icon(
                      icon: const Icon(Icons.phone_android_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3), // Blue
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Disable if any button is loading
                      onPressed: isLoading
                          ? null
                          : _sendPhoneVerification, // <-- CALL THE NEW FUNCTION
                      label: _isSendingOTP
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text('Verify with Phone (OTP)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
