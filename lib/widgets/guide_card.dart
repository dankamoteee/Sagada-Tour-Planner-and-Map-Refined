import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tour_guide_model.dart';

class GuideCard extends StatelessWidget {
  final TourGuide? guide;
  final VoidCallback onAssignGuide;
  final VoidCallback onRemoveGuide; // 👈 NEW CALLBACK

  const GuideCard({
    super.key,
    required this.guide,
    required this.onAssignGuide,
    required this.onRemoveGuide, // 👈 Add this
  });

  @override
  Widget build(BuildContext context) {
    final double topPosition = MediaQuery.of(context).padding.top + 170;

    if (guide == null) {
      return Positioned(
        top: topPosition,
        left: 12,
        right: 12,
        child: Card(
          color: Colors.orange.shade50,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.person_add, color: Colors.orange),
            title: const Text(
              "No Guide Assigned",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text("Tap to select your guide for today.",
                style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onAssignGuide,
          ),
        ),
      );
    }

    return Positioned(
      top: topPosition,
      left: 12,
      right: 12,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: guide!.imageUrl.isNotEmpty
                    ? NetworkImage(guide!.imageUrl)
                    : null,
                child:
                    guide!.imageUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("MY GUIDE",
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold)),
                    Text(
                      guide!.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      guide!.phone,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // ⭐️ Actions
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => _launchCall(guide!.phone),
              ),
              // ⭐️ Popup Menu to Remove/Change
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'change') onAssignGuide();
                  if (value == 'remove') onRemoveGuide();
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                      value: 'change', child: Text('Change Guide')),
                  const PopupMenuItem(
                      value: 'remove', child: Text('Remove Guide')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    // ⭐️ FIX: LaunchMode.externalApplication is required for some Android versions
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }
}
