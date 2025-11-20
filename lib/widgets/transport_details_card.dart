import 'package:flutter/material.dart';

class TransportDetailsCard extends StatelessWidget {
  final Map<String, dynamic>? transportData;
  final VoidCallback onClose;

  const TransportDetailsCard({
    super.key,
    required this.transportData,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (transportData == null) return const SizedBox.shrink();

    final route = transportData!;
    final String vehicleType = route['routeName'] ?? 'Transport';
    final String fare = route['fareDetails'] ?? 'N/A';
    final String schedule = route['schedule'] ?? 'N/A';
    final Color themeColor = Theme.of(context).primaryColor;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Card(
        margin: const EdgeInsets.all(12.0),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title and Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Route: $vehicleType",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: themeColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: onClose,
                  ),
                ],
              ),
              // Fare Details
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.money_outlined, color: Colors.green),
                title: const Text("Fare Details",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(fare),
              ),
              // Schedule Details
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.schedule_outlined, color: Colors.blue),
                title: const Text("Schedule",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(schedule),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
