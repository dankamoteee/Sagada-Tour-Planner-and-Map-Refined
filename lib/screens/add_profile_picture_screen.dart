// lib/screens/add_profile_picture_screen.dart

import 'dart:io'; // Used to handle the image file
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'map_homescreen.dart';
import 'gradient_background.dart';

class AddProfilePictureScreen extends StatefulWidget {
  const AddProfilePictureScreen({super.key});

  @override
  State<AddProfilePictureScreen> createState() =>
      _AddProfilePictureScreenState();
}

class _AddProfilePictureScreenState extends State<AddProfilePictureScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isLoading = false;

  /// Navigates to the MapScreen
  void _skipToMap() {
    if (!mounted) return;
    // Use pushReplacement so the user can't press "back" to this screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  /// Picks an image from the user's gallery
  Future<void> _pickImage() async {
    final XFile? selectedImage =
        await _picker.pickImage(source: ImageSource.gallery);

    if (selectedImage != null) {
      setState(() {
        _imageFile = selectedImage;
      });
    }
  }

  /// Uploads the selected image, updates Firestore, and then navigates
  Future<void> _uploadAndContinue() async {
    // If no image is selected, just treat it as a skip
    if (_imageFile == null) {
      _skipToMap();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _skipToMap(); // Should not happen, but just in case
        return;
      }

      // --- ⭐️ THIS IS THE FIX ⭐️ ---
      // We add a file name (like 'profile.jpg') to match your rules
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures') // Folder
          .child(user.uid) // {userId}
          .child('profile.jpg'); // {fileName}
      // --- ⭐️ END OF FIX ⭐️ ---

      // 2. Upload the file
      final uploadTask = await storageRef.putFile(File(_imageFile!.path));

      // 3. Get the Download URL
      final String downloadUrl = await uploadTask.ref.getDownloadURL();

      // 4. Update the user's document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'profilePictureUrl': downloadUrl,
      });

      // 5. Navigate to the map
      _skipToMap();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                  const Text(
                    'Almost there!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add a profile picture to personalize your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- The Image Picker ---
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? FileImage(File(_imageFile!.path))
                          : null,
                      child: _imageFile == null
                          ? Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _pickImage,
                    child: Text(
                      _imageFile == null ? 'Choose a Photo' : 'Change Photo',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Continue Button ---
                  ElevatedButton(
                    onPressed: _isLoading ? null : _uploadAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 58, 106, 85),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _imageFile == null
                                ? 'Continue without Photo'
                                : 'Save and Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  // --- Skip Button ---
                  // This is a secondary way to skip
                  if (_imageFile != null)
                    TextButton(
                      onPressed: _isLoading ? null : _skipToMap,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(color: Colors.grey),
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
