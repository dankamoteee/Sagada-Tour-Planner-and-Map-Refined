import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/profile_screen.dart';
import '../screens/recently_viewed_screen.dart';
import '../screens/hotline_screen.dart';
import '../screens/tour_guides_screen.dart';
import '../screens/itineraries_list_screen.dart';
import '../screens/guidelines_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/updates_screen.dart';

class ProfileMenu extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final Function(Map<String, dynamic>) onDrawItinerary;

  const ProfileMenu({super.key, this.userData, required this.onDrawItinerary});

  @override
  Widget build(BuildContext context) {
    final userPhotoUrl = userData?['profilePictureUrl'];
    final userName = userData?['fullName'] ?? 'Guest';
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.75,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // --- ⭐️ NEW HEADER LAYOUT ⭐️ ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                children: [
                  // LEFT: Back Button
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // RIGHT: Action Buttons Grouped Together
                  // We use a Row here so they stick to the right side
                  Row(
                    children: [
                      _buildCatchyActionButton(
                        context,
                        icon: Icons.info_outlined,
                        color: Colors.teal,
                        tooltip: "Guidelines",
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const GuidelinesScreen()),
                          );
                          if (result is Map<String, dynamic> &&
                              result['action'] == 'filter') {
                            Navigator.pop(context, result);
                          }
                        },
                      ),
                      const SizedBox(width: 8), // Spacing between buttons
                      _buildCatchyActionButton(
                        context,
                        icon: Icons.campaign_outlined,
                        color: Colors.orange,
                        tooltip: "News",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const UpdatesScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              // --- END OF NEW HEADER ---

              const SizedBox(height: 40),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(thickness: 1, height: 20),
              const SizedBox(height: 10),

              // ... (Rest of your Menu Buttons: Profile, Itinerary, etc.) ...
              _buildImageButton("Profile", "assets/images/profile_bg.png", () {
                Navigator.pop(context);
                if (userId != null && userData != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                              userId: userId, userData: userData!)));
                }
              }),
              _buildImageButton(
                  "My Itinerary", "assets/images/itinerary_bg.png", () async {
                Navigator.of(context).pop();
                final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const ItinerariesListScreen()));
                if (result is Map<String, dynamic>) {
                  onDrawItinerary(result);
                }
              }),
              _buildImageButton(
                  "Recently Viewed", "assets/images/recent_bg.png", () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RecentlyViewedScreen()));
                if (result is Map<String, dynamic>) {
                  Navigator.pop(context, result);
                } else {
                  Navigator.pop(context);
                }
              }),
              _buildImageButton("Tour Guides", "assets/images/tourguide_bg.png",
                  () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TourGuidesScreen()));
              }),
              _buildImageButton(
                "Sagada Hotline Numbers",
                "assets/images/hotline_bg.png",
                () {
                  // DO NOT pop. Just push the new screen.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HotlineScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Profile Picture (Unchanged)
        Positioned(
          top: -50,
          left: 0,
          right: 0,
          child: Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: (userPhotoUrl != null && userPhotoUrl.isNotEmpty)
                  ? Colors.white
                  : const Color(0xFF3A6A55),
              backgroundImage: (userPhotoUrl != null && userPhotoUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(userPhotoUrl)
                  : null,
              child: (userPhotoUrl == null || userPhotoUrl.isEmpty)
                  ? (userName.isNotEmpty && userName != 'Guest')
                      ? Text(userName[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: Colors.white))
                      : const Icon(Icons.person, size: 60, color: Colors.grey)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ⭐️ NEW HELPER FOR CATCHY BUTTONS ⭐️
  Widget _buildCatchyActionButton(BuildContext context,
      {required IconData icon,
      required Color color,
      required String tooltip,
      required VoidCallback onTap}) {
    return Material(
      color: color.withOpacity(0.1), // Light background
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(0.5), width: 1), // Colored border
          ),
          child: Icon(icon, color: color, size: 26), // Colored Icon
        ),
      ),
    );
  }

  /// Helper widget for building the menu buttons with background images.
  /// This is the exact same method you had before, now part of this widget.
  Widget _buildImageButton(String text, String imagePath, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.3), // Dark overlay for text readability
            BlendMode.darken,
          ),
        ),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
