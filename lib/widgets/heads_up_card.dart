import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class HeadsUpCard extends StatelessWidget {
  final Map<String, dynamic> eventData;
  final String itineraryName;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const HeadsUpCard({
    super.key,
    required this.eventData,
    required this.itineraryName,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Extract and Format Data
    final Timestamp? ts = eventData['eventTime'] as Timestamp?;
    if (ts == null) return const SizedBox.shrink();

    final DateTime eventTime = ts.toDate();
    final String eventName = eventData['destinationPoiName'] ?? 'Your Event';
    final String timeAgo = timeago.format(eventTime, allowFromNow: true);
    final String specificTime =
        DateFormat.jm().format(eventTime); // e.g. 10:30 AM

    final Color primaryColor = Theme.of(context).primaryColor;

    // 2. Build the UI
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70, // Below search bar
      left: 12,
      right: 12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor
                      .withAlpha(230), // Using withAlpha for compatibility
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "at $specificTime ($timeAgo)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "From: $itineraryName",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClear,
                    tooltip: 'Clear active trip',
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
