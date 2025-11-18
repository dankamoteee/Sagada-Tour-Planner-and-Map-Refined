import 'package:flutter/material.dart';
import 'guideline_detail_screen.dart';

class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({super.key});

  Widget _buildCategoryTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
    Map<String, String>? keyInfo, // ⭐️
    Map<String, dynamic>? action, // ⭐️
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () async {
        // ⭐️ Make async
        // ⭐️ Wait for the result from the Detail screen
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GuidelineDetailScreen(
              title: title,
              keyInfo: keyInfo,
              action: action,
              children: children,
            ),
          ),
        );

        // ⭐️ If there is a result (action button clicked), pass it back up
        if (result != null && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
    );
  }

  /*
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
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sagada Tourist Guidelines'),
      ),
      body: ListView(
        children: [
          _buildCategoryTile(
            context: context,
            icon: Icons.credit_card_outlined,
            title: 'Money & ATMs',
            subtitle: 'How to pay for things in Sagada.',
            // ⭐️ 1. KEY INFO ADDED
            keyInfo: {
              'title': 'Bring Cash!',
              'content':
                  'Most establishments do not accept credit cards. GCash is widely accepted, but cash is king.'
            },
            // ⭐️ 2. ACTION ADDED
            action: {
              'label': 'Show ATMs & Banks on Map',
              'result': {
                'action': 'filter',
                'filterType': 'Services'
              } // Make sure you add 'Services' to your map filters
            },
            children: const [
              GuidelineHeader('Credit Cards & Cash'),
              GuidelineText(
                  "Please make sure you've brought enough cash as establishments in Sagada do not accept credit cards. On the bright side, most establishments including small stores accept payments via GCash."),
              GuidelineHeader('ATMs'),
              GuidelineText(
                  'There is a DBP ATM at the Tourist information Center... a Pinoy Coop ATM at the 3rd Floor of the Eduardo Longid Centrum Building... and an LBP ATM at the New Municipal Building.'),
              GuidelineHeader('Bank'),
              GuidelineText(
                  'The Rural Bank of Sagada is the only bank located within the Municipality...'),
            ],
          ),
          const Divider(height: 1),
          _buildCategoryTile(
            context: context,
            icon: Icons.directions_walk_outlined,
            title: 'Getting Around & Parking',
            subtitle: 'Walking, driving, and parking rules.',
            // ⭐️ 1. KEY INFO
            keyInfo: {
              'title': 'Sagada is a Walk Town',
              'content':
                  'Please walk whenever possible. Streets are narrow and on-street parking causes traffic.'
            },
            // ⭐️ 2. ACTION
            action: {
              'label': 'Show Parking Areas on Map',
              'result': {
                'action': 'filter',
                'filterType': 'Parking'
              } // Make sure you add 'Parking' to your map filters
            },
            children: const [
              GuidelineHeader('Sagada is a Walk Town'),
              GuidelineText(
                  'Please walk whenever possible and use your vehicles responsibly. Walking is an essential part of the Sagada experience.'),
              GuidelineText(
                  'Our streets are narrow and on-street parking creates serious traffic problems so please park on designated parking areas.'),
              GuidelineHeader('Parking Areas'),
              GuidelineText(
                  '· Church Of Saint Mary the Virgin Compound\n· Saint Joseph Resthouse\n· Makamkamlis Road (Street Parking)\n· Parking Area Near Lemon Pie House\n· Parking Area Near Sagada Hub'),
            ],
          ),
          const Divider(height: 1),
          _buildCategoryTile(
            context: context,
            icon: Icons.cloud_outlined,
            title: 'Climate & What to Wear',
            subtitle: 'Weather info and what to pack.',
            children: const [
              GuidelineHeader('Climate and Season'),
              GuidelineText(
                  'March to Early May: Dry Season\nLate May to September: Rainy Season\nOctober to February: Cool and Windy'),
              GuidelineText(
                  'Sagada is coldest in the months of December to February (as low as 10° C).'),
              GuidelineHeader('What to Wear'),
              GuidelineText(
                  '· Wear jackets. It can get rather cold.\n· For trekking, use appropriate shoes or sandals.\n· For spelunking (caving), use dri-fit clothing and flip-flops/sandals.\n· Kindly avoid using skimpy clothing when walking in town.'),
            ],
          ),
          const Divider(height: 1),
          _buildCategoryTile(
            context: context,
            icon: Icons.signal_cellular_alt_outlined,
            title: 'Connectivity & Business Hours',
            subtitle: 'Mobile data and shop hours.',
            children: const [
              GuidelineHeader('Mobile Connection'),
              GuidelineText(
                  'SMART and Globe have excellent reception (4G+) in town. However, the outskirts of Sagada still have weak or dead spots.'),
              GuidelineHeader('Business Hours'),
              GuidelineText(
                  'Government Offices: 8AM-5PM (Weekdays)\nTourist Information Center: 7AM-6PM (Daily)\nBank: 8AM-5PM (Tue-Sat)\n...'),
            ],
          ),
        ],
      ),
    );
  }
}
