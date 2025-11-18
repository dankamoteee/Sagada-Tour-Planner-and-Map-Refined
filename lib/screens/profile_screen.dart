import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ⭐️ --- REMOVED PROVIDER IMPORTS --- ⭐️

class ProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final TextEditingController _usernameController = TextEditingController();
  String? _selectedMapStyle;

  final Color themeColor = const Color(0xFF3A6A55);
  late Map<String, dynamic> _userData;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _usernameController.text = _userData['username'] ?? '';
    _loadMapStylePreference();
  }

  Future<void> _loadMapStylePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Defaults to 'tourism.json' if nothing is set
      _selectedMapStyle = prefs.getString('mapStyle') ?? 'tourism.json';
    });
  }

  Future<void> _setMapStylePreference(String? style) async {
    if (style == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mapStyle', style);
    setState(() {
      _selectedMapStyle = style;
    });
  }

  Future<void> _changeProfilePicture() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    if (mounted) setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(widget.userId)
          .child('profile.jpg');

      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await DefaultCacheManager().removeFile(url);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({'profilePictureUrl': url}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _userData['profilePictureUrl'] = url;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to upload image: $e")));
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _showEditUsernameDialog() async {
    _usernameController.text =
        _userData['username'] ?? ''; // Ensure controller is up-to-date

    final newUsername = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: _usernameController,
          decoration: const InputDecoration(hintText: "Enter a username"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, _usernameController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newUsername != null && newUsername.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update({'username': newUsername});

        if (mounted) {
          setState(() {
            _userData['username'] = newUsername; // Update local data
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Username updated!")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error updating username: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = _userData;

    final String fullName = userData['fullName'] ?? 'No Name';
    final String username = userData['username'] ?? 'no_username';
    final String email = userData['email'] ?? 'No email';
    final String phone = userData['phone'] ?? 'No phone number';
    final String? photoUrl = userData['profilePictureUrl'];
    final Timestamp createdAt = userData['createdAt'] ?? Timestamp.now();
    final String memberSince = DateFormat(
      'MMMM d, yyyy',
    ).format(createdAt.toDate());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: themeColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/profile_background.avif',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.grey.shade300,
                            child: ClipOval(
                              child: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: photoUrl,
                                      fit: BoxFit.cover,
                                      width: 92,
                                      height: 92,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade300,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _changeProfilePicture,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white,
                                child: _isUploading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        Icons.edit,
                                        color: themeColor,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              _buildInfoCard(
                context,
                title: "User Details",
                children: [
                  _buildEditableDetailRow(
                    Icons.person_outline,
                    "Username",
                    username,
                    onEdit: _showEditUsernameDialog,
                  ),
                  _buildDetailRow(Icons.email_outlined, "Email", email,
                      isEmail: true),
                  _buildDetailRow(Icons.phone_outlined, "Phone", phone),
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    "Member Since",
                    memberSince,
                  ),
                ],
              ),
              _buildInfoCard(
                context,
                title: "App Preferences",
                children: [
                  // ⭐️ --- MODIFIED THIS SECTION --- ⭐️
                  _buildMapStyleChips(),
                  // SwitchListTile for Dark Mode has been removed
                  // ⭐️ --- END OF MODIFICATION --- ⭐️
                ],
              ),
              _buildInfoCard(
                context,
                title: "Account Management",
                children: [
                  _buildAccountActionRow(
                    "Change Password",
                    Icons.lock_outline,
                    Colors.grey.shade700,
                    () async {
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("No email on file to send reset link.")),
                        );
                        return;
                      }
                      try {
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(email: email);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text("Password reset email sent to $email.")),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: ${e.toString()}")),
                        );
                      }
                    },
                  ),
                  _buildAccountActionRow(
                    "Sign Out",
                    Icons.logout,
                    Colors.red,
                    () async {
                      final bool? shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Sign Out'),
                          content: const Text(
                            'Are you sure you want to sign out?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (shouldLogout == true) {
                        await FirebaseAuth.instance.signOut();
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        }
                      }
                    },
                  ),
                  _buildAccountActionRow(
                    "Delete Account",
                    Icons.delete_forever_outlined,
                    Colors.red,
                    () {
                      // TODO: Implement full account deletion logic.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Delete account feature not implemented yet.")),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    Widget? actionButton,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                if (actionButton != null) actionButton,
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value,
      {bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: isEmail ? TextOverflow.ellipsis : TextOverflow.clip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDetailRow(IconData icon, String title, String value,
      {required VoidCallback onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            iconSize: 20,
            color: Colors.grey.shade600,
            tooltip: "Edit $title",
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  // ⭐️ --- WIDGET REVAMPED --- ⭐️
  /// Builds the ChoiceChips for map style selection
  Widget _buildMapStyleChips() {
    // A map of the style file name to its display name
    final Map<String, String> styles = {
      'tourism.json': 'Tourism',
      'clean.json': 'Clean',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.map_outlined, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 16),
            Text(
              "Default Map Style",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          children: styles.keys.map((styleFile) {
            return ChoiceChip(
              label: Text(styles[styleFile]!),
              labelStyle: TextStyle(
                color:
                    _selectedMapStyle == styleFile ? themeColor : Colors.black,
              ),
              selected: _selectedMapStyle == styleFile,
              onSelected: (bool selected) {
                if (selected) {
                  _setMapStylePreference(styleFile);
                }
              },
              selectedColor: themeColor.withOpacity(0.1),
              backgroundColor: Colors.grey.shade200,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: _selectedMapStyle == styleFile
                      ? themeColor
                      : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  // ⭐️ --- END OF REVAMP --- ⭐️

  Widget _buildAccountActionRow(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w500, color: color)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
