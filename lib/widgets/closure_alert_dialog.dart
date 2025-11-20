import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClosureAlertDialog extends StatelessWidget {
  final Map<String, dynamic> closureData;

  const ClosureAlertDialog({
    super.key,
    required this.closureData,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Extract Data
    final String name = closureData['name'] ?? 'Closure Information';
    final String type = closureData['type'] ?? 'Notice';
    final String details = closureData['details'] ?? 'No details provided.';
    String postedAtText = 'Report date not available.';

    if (closureData['postedAt'] != null &&
        closureData['postedAt'] is Timestamp) {
      final DateTime postedAt = (closureData['postedAt'] as Timestamp).toDate();
      postedAtText =
          'Reported on: ${DateFormat.yMMMd().add_jm().format(postedAt)}';
    }

    // 2. Determine Styles based on Type
    IconData closureIcon;
    Color iconColor;
    switch (type.toLowerCase()) {
      case 'landslide':
        closureIcon = Icons.warning_amber_rounded;
        iconColor = Colors.brown.shade600;
        break;
      case 'event':
        closureIcon = Icons.event;
        iconColor = Colors.blue.shade700;
        break;
      case 'construction':
        closureIcon = Icons.construction;
        iconColor = Colors.orange.shade800;
        break;
      default:
        closureIcon = Icons.traffic;
        iconColor = Colors.red.shade700;
    }

    final Color primaryColor = Theme.of(context).primaryColor;

    // 3. Build Dialog
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      title: Column(
        children: [
          Icon(
            closureIcon,
            color: iconColor,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Type" Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              type.toUpperCase(),
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Details
          Text(
            details,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          // Posted At
          Text(
            postedAtText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.black54,
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text('Okay, Got It'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
