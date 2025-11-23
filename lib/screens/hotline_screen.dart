import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HotlineScreen extends StatefulWidget {
  const HotlineScreen({super.key});

  @override
  State<HotlineScreen> createState() => _HotlineScreenState();
}

class _HotlineScreenState extends State<HotlineScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ⭐️ HELPER: General URL Launcher
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for some devices
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open $urlString")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ⭐️ SliverAppBar for a nice collapsing header effect
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200.0,
            backgroundColor: const Color(0xFF3A6A55),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Emergency Hotlines",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/hotline_background.jpg', // Ensure this asset exists
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
                ],
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search agency...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // List of Hotlines
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('Hotline').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text("No hotlines found.")),
                );
              }

              final allDocs = snapshot.data!.docs;
              // Client-side filtering
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name =
                    (data['agencyName'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text("No matching results.")),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doc = filteredDocs[index];
                    return _buildHotlineCard(doc);
                  },
                  childCount: filteredDocs.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHotlineCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String agencyName = data['agencyName'] ?? 'Unknown Agency';
    final String address = data['address'] ?? 'Sagada, Mountain Province';
    final String? imageUrl = data['imageUrl'];

    // ⭐️ NEW: PARSE CONTACTS MAP ⭐️
    final Map<String, dynamic> contacts =
        data['contacts'] is Map ? data['contacts'] as Map<String, dynamic> : {};

    final String? phone = contacts['contactNumber']?.toString();
    final String? email = contacts['email']?.toString();
    final String? fbName = contacts['facebook']?.toString();
    // Note: 'messenger' field usually just duplicates the name or ID,
    // but we can assume it links to the same FB profile unless you have a specific m.me link.

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image Header (Optional: Only if URL exists)
          if (imageUrl != null && imageUrl.isNotEmpty)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheHeight: 400, // 🚀 Optimization
                placeholder: (context, url) =>
                    Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.local_hospital,
                      size: 40, color: Colors.grey),
                ),
              ),
            ),

          // 2. Agency Info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agencyName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3A6A55),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // ⭐️ 3. DYNAMIC CONTACT BUTTONS ⭐️
                // We wrap them in a scrolling row in case there are many
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // A. Phone Button
                      if (phone != null && phone.isNotEmpty)
                        _buildContactButton(
                          icon: Icons.phone,
                          label: "Call",
                          color: Colors.green,
                          onTap: () => _launchUrl("tel:$phone"),
                        ),

                      // B. Email Button
                      if (email != null && email.isNotEmpty)
                        _buildContactButton(
                          icon: Icons.email,
                          label: "Email",
                          color: Colors.orange,
                          onTap: () => _launchUrl("mailto:$email"),
                        ),

                      // C. Facebook Button
                      if (fbName != null && fbName.isNotEmpty)
                        _buildContactButton(
                          icon: Icons.facebook,
                          label: "Facebook",
                          color: Colors.blue,
                          // This searches the page on FB or opens browser
                          onTap: () => _launchUrl(
                              "https://www.facebook.com/search/top?q=$fbName"),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⭐️ Helper for Uniform Buttons
  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1), // Light pastel bg
          foregroundColor: color, // Dark text/icon color
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}
