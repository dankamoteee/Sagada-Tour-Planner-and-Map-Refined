import 'package:flutter/material.dart';

class PoiTipCard extends StatelessWidget {
  final Map<String, dynamic> poiData;

  const PoiTipCard({super.key, required this.poiData});

  @override
  Widget build(BuildContext context) {
    String? title;
    String? content;
    IconData? icon;

    // Check for specific POIs by name
    // (Ideally, this data should come from the database in the future,
    // but for now, we are preserving your existing hardcoded logic.)
    switch (poiData['name']) {
      case 'Sumaguing Cave':
      case 'Lumiang to Sumaguing Cave Connection':
        title = 'What to Wear & Warning';
        content =
            'Wear dri-fit clothing and flip-flops, outdoor sandals, or water shoes. This tour carries physical risks and is not recommended for those with underlying conditions.';
        icon = Icons.warning_amber_rounded;
        break;
      case 'Hanging Coffins':
        title = 'Respect Sacred Ground';
        content =
            'This is a sacred burial ground. Please be respectful, minimize noise, and avoid shouting.';
        icon = Icons.volume_off_outlined;
        break;
      case 'Sagada Pottery':
        title = 'Pottery Tip';
        content =
            'Be careful not to break any pottery. Always ask permission before touching materials.';
        icon = Icons.back_hand_outlined;
        break;
    }

    // If no specific tip, return an empty container
    if (title == null) {
      return const SizedBox.shrink();
    }

    // Build the card
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content!,
            style: const TextStyle(
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
