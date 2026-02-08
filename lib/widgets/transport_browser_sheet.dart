// In lib/widgets/transport_browser_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TransportBrowserSheet extends StatefulWidget {
  const TransportBrowserSheet({super.key});

  @override
  State<TransportBrowserSheet> createState() => _TransportBrowserSheetState();
}

class _TransportBrowserSheetState extends State<TransportBrowserSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRoutes = [];
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _fetchTransportData();
  }

  Future<void> _fetchTransportData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('transportRoutes').get();
      final routes = snapshot.docs.map((doc) => doc.data()).toList();
      if (mounted) {
        setState(() {
          _allRoutes = routes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching transport routes: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTypesList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final types = _allRoutes.map((r) => r['type'] as String).toSet().toList();

    return ListView.builder(
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        return ListTile(
          leading: Icon(
            type == 'Jeepney' ? Icons.directions_bus : Icons.local_taxi,
          ),
          title: Text(
            type,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => setState(() => _selectedType = type),
        );
      },
    );
  }

  Widget _buildRoutesList() {
    final filteredRoutes =
        _allRoutes.where((r) => r['type'] == _selectedType).toList();

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: Text(
            "Back to categories",
            style: TextStyle(color: Theme.of(context).primaryColor),
          ),
          onTap: () => setState(() => _selectedType = null),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: filteredRoutes.length,
            itemBuilder: (context, index) {
              final route = filteredRoutes[index];
              final polyline = route['polyline'] as String?;
              final canShowOnMap = polyline != null && polyline.isNotEmpty;

              // ⭐️ PREPARE TERMINAL INFO ⭐️
              final String start = route['originTerminal'] ?? 'Origin';
              final String end = route['destinationTerminal'] ?? 'Destination';
              // Fallback if specific fields aren't set yet
              final String generalTerminal = route['terminal'] ?? '';

              return ListTile(
                leading: const Icon(Icons.route_outlined),
                title: Text(route['routeName'] ?? 'Unnamed Route'),
                // ⭐️ UPDATED SUBTITLE ⭐️
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (route['fareDetails'] != null)
                      Text(route['fareDetails'] ?? ''),
                    const SizedBox(height: 6),

                    // Show specific start/end if available
                    if (route.containsKey('originTerminal') ||
                        route.containsKey('destinationTerminal')) ...[
                      Row(children: [
                        const Icon(Icons.circle, size: 8, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text("From: $start",
                                style: const TextStyle(fontSize: 12))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.circle, size: 8, color: Colors.red),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text("To: $end",
                                style: const TextStyle(fontSize: 12))),
                      ]),
                    ]
                    // Otherwise show generic terminal info
                    else if (generalTerminal.isNotEmpty) ...[
                      Row(children: [
                        const Icon(Icons.info_outline,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text("Terminal: $generalTerminal",
                                style: const TextStyle(fontSize: 12))),
                      ]),
                    ]
                  ],
                ),
                isThreeLine: true,
                trailing: canShowOnMap ? const Icon(Icons.map_outlined) : null,
                onTap: () {
                  if (canShowOnMap) {
                    Navigator.pop(context, route);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('This route has no map data.')),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          MediaQuery.of(context).size.height * 0.6, // Take up 60% of the screen
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _selectedType == null ? 'Transport Options' : _selectedType!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedType == null
                  ? _buildTypesList()
                  : _buildRoutesList(),
            ),
          ),
        ],
      ),
    );
  }
}
