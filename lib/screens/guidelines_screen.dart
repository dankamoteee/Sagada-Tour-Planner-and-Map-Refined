import 'package:flutter/material.dart';

class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Tourist Guidelines",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/itinerary_background.jpg',
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

          // --- Updated with brochure text ---
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // --- Section 1: Registration (You were right, this should be first) ---
              _buildGuidelineCard(
                context: context,
                icon: Icons.app_registration,
                title: "Register as a Tourist",
                points: [
                  "All visitors MUST register at the Municipal Tourism Office upon arrival.",
                  "A standard environmental fee is collected per person, which is valid for your entire stay.",
                  "Your registration receipt is required for entry to most sites and for guide services. Keep it with you at all times.",
                ],
              ),

              // --- Section 2: Manage Expectations ---
              _buildGuidelineCard(
                context: context,
                icon: Icons.info_outline_rounded,
                title: "Manage Your Expectations",
                points: [
                  "Sagada is a remote mountain town, not a luxury resort. Services are local, simple, and authentic.",
                  "Internet (Wi-Fi and mobile data) can be slow or unavailable, especially during bad weather. Embrace the disconnect!",
                  "Water and power interruptions can happen. Your accommodation will do its best to assist.",
                  "Not all establishments accept credit cards. Bring enough cash.",
                ],
              ),

              // --- Section 3: Safety ---
              _buildGuidelineCard(
                context: context,
                icon: Icons.health_and_safety_outlined,
                title: "Please Help Us Keep You Safe",
                points: [
                  "Hire accredited guides for ALL eco-tours, caves, and long hikes. They are required for your safety.",
                  "Do not hire unaccredited guides. Always book through the Tourism Office or an accredited organization.",
                  "People can and do get lost. Stick to marked trails and always go with your guide.",
                ],
              ),

              // --- Section 4: Culture & Respect ---
              _buildGuidelineCard(
                context: context,
                icon: Icons.groups_outlined,
                title: "Respect the People and Culture",
                points: [
                  "Refrain from making loud noises, especially near religious, sacred, or spiritual places.",
                  "Ask permission from elders before joining or photographing any rituals.",
                  "Do NOT touch or disturb coffins or burial sites. Show utmost respect.",
                  "Dress modestly when walking around town. Swimwear is for waterfalls only.",
                ],
              ),

              // --- Section 5: Practical Reminders ---
              _buildGuidelineCard(
                context: context,
                icon: Icons.directions_walk_rounded,
                title: "Walking & Parking",
                points: [
                  "Sagada is a 'walking town.' Most central spots are best reached on foot. Be prepared to walk up and down hills.",
                  "Parking is very limited. 'Pay Parking' areas are available. Do not park along the main road as it causes traffic.",
                  "Follow all traffic signs and one-way streets. Be courteous to other drivers and pedestrians.",
                ],
              ),

              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  /// A helper widget to create a nice-looking info card
  Widget _buildGuidelineCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<String> points,
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
            // --- Title Row ---
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // --- Bullet Points ---
            ...points.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
