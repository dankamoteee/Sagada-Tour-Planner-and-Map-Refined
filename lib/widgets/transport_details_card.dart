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
    final String routeName = route['routeName'] ?? 'Transport';
    final String type = route['type'] ?? 'Vehicle';

    // New Fields
    final String description = route['description'] ?? '';
    final String fareDetails = route['fareDetails'] ?? 'N/A';
    final String fareSystem = route['fareSystem'] ?? 'Fixed';
    final String schedule = route['schedule'] ?? 'N/A';
    final String serviceArea = route['serviceArea'] ?? '';

    final Color themeColor = Theme.of(context).primaryColor;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Card(
        margin: const EdgeInsets.all(12.0),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // ⭐️ LIMIT HEIGHT: Use a ConstrainedBox so description doesn't overflow
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * 0.5, // Max 50% screen
          ),
          child: SingleChildScrollView(
            // ⭐️ ADD SCROLLING
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Header ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routeName, // e.g., "Any point within Sagada"
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: themeColor,
                            ),
                          ),
                          Text(
                            type, // e.g., "Ongbak/Baja"
                            style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const Divider(),

                // --- Description (New) ---
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                        fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                ],

                // --- Fare Section ---
                _buildSectionHeader("Fare Information",
                    Icons.monetization_on_outlined, Colors.green),
                _buildInfoRow("System", fareSystem),
                _buildInfoRow("Details", fareDetails),
                const SizedBox(height: 12),

                // --- Schedule & Coverage ---
                _buildSectionHeader(
                    "Operations", Icons.access_time, Colors.blue),
                _buildInfoRow("Schedule", schedule),
                if (serviceArea.isNotEmpty)
                  _buildInfoRow("Service Area", serviceArea),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ⭐️ Helper for Section Headers
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ⭐️ Helper for Data Rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(
          bottom: 6.0, left: 26.0), // Indent to align with text
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80, // Fixed width for labels
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
