import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// This is the "fake" POI we will use as a placeholder
final Map<String, dynamic> _myLocationPoi = {
  'id': 'MY_LOCATION',
  'name': 'My Location',
  'type': 'Your current location',
  // Add dummy coordinates to prevent null errors in other parts of the app
  'coordinates': const GeoPoint(0, 0),
};

class CustomRouteSheet extends StatefulWidget {
  const CustomRouteSheet({super.key});

  @override
  State<CustomRouteSheet> createState() => _CustomRouteSheetState();
}

class _CustomRouteSheetState extends State<CustomRouteSheet> {
  Map<String, dynamic>? _startPoi;
  Map<String, dynamic>? _endPoi;

  /// Shows a full-screen search page to select a POI
  // --- ⭐️ UPDATED: Now accepts an 'excludedPoi' ---
  Future<void> _showPoiSelector(
    BuildContext context,
    bool isStart, {
    Map<String, dynamic>? excludedPoi,
  }) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        // Pass the POI to exclude to the search page
        builder: (context) => _PoiSearchPage(excludedPoi: excludedPoi),
      ),
    );

    if (result != null) {
      setState(() {
        if (isStart) {
          _startPoi = result;
        } else {
          _endPoi = result;
        }
      });
    }
  }

  // This widget is unchanged
  Widget _buildPointSelector(
    BuildContext context, {
    required String
        label, // This is the hint text, e.g., "Choose starting point"
    required bool isStart, // To decide the default icon
    required Map<String, dynamic>? poi,
    required VoidCallback onTap,
  }) {
    final bool isSelected = poi != null;
    final bool isMyLocation = isSelected && poi['id'] == _myLocationPoi['id'];

    IconData displayIcon;
    if (isMyLocation) {
      displayIcon = Icons.my_location;
    } else if (isStart) {
      displayIcon = Icons.my_location; // Default icon for "Start"
    } else {
      displayIcon = Icons.location_on; // Default icon for "End"
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            Icon(displayIcon, color: Theme.of(context).primaryColor), // Themed
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                isSelected ? poi['name']! : label, // 'label' is the hint
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? Colors.black : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              InkWell(
                onTap: () {
                  setState(() {
                    if (isStart) {
                      _startPoi = null;
                    } else {
                      _endPoi = null;
                    }
                  });
                },
                child: const Icon(Icons.clear, color: Colors.grey, size: 20),
              )
            else
              const Icon(Icons.search, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Plan a Route',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          _buildPointSelector(
            context,
            label: 'Choose starting point',
            isStart: true,
            poi: _startPoi,
            // --- ⭐️ UPDATED: Pass the *other* POI to be excluded ---
            onTap: () => _showPoiSelector(context, true, excludedPoi: _endPoi),
          ),
          const SizedBox(height: 12),
          _buildPointSelector(
            context,
            label: 'Choose destination',
            isStart: false,
            poi: _endPoi,
            // --- ⭐️ UPDATED: Pass the *other* POI to be excluded ---
            onTap: () =>
                _showPoiSelector(context, false, excludedPoi: _startPoi),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.directions),
              label: const Text('Find Route'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: (_startPoi != null && _endPoi != null)
                  ? () {
                      Navigator.of(context).pop({
                        'start': _startPoi,
                        'end': _endPoi,
                      });
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// --- This is the internal search page ---
class _PoiSearchPage extends StatefulWidget {
  // --- ⭐️ UPDATED: Accepts an excluded POI ---
  final Map<String, dynamic>? excludedPoi;
  const _PoiSearchPage({this.excludedPoi});

  @override
  State<_PoiSearchPage> createState() => _PoiSearchPageState();
}

class _PoiSearchPageState extends State<_PoiSearchPage> {
  String _query = '';
  List<Map<String, dynamic>> _allPois = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPois();
  }

  Future<void> _fetchPois() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('POIs').get();

      final poiList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (mounted) {
        setState(() {
          _allPois = [
            _myLocationPoi, // Add our "fake" POI
            ...poiList,
          ];

          // --- ⭐️ NEW: Filter out the excluded POI ---
          if (widget.excludedPoi != null) {
            _allPois
                .removeWhere((poi) => poi['id'] == widget.excludedPoi!['id']);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching POIs for search: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // This widget is unchanged
  Widget _getIconForPoi(Map<String, dynamic> poi) {
    if (poi['id'] == _myLocationPoi['id']) {
      return Icon(Icons.my_location, color: Theme.of(context).primaryColor);
    }

    String type = poi['type'] ?? 'Unknown';
    IconData iconData;
    switch (type) {
      case 'Tourist Spots':
        iconData = Icons.landscape;
        break;
      case 'Business Establishments':
        iconData = Icons.store;
        break;
      case 'Accommodations':
        iconData = Icons.hotel;
        break;
      case 'Transport Routes and Terminals':
        iconData = Icons.directions_bus;
        break;
      case 'Agencies and Offices':
        iconData = Icons.corporate_fare;
        break;
      default:
        iconData = Icons.location_pin;
    }
    return Icon(iconData, color: Colors.grey[600]);
  }

  @override
  Widget build(BuildContext context) {
    // This logic is unchanged, as _allPois is now pre-filtered
    final List<Map<String, dynamic>> suggestions = _query.isEmpty
        ? _allPois
        : _allPois.where((poi) {
            final name = poi['name']?.toLowerCase() ?? '';
            final type = poi['type']?.toLowerCase() ?? '';
            final q = _query.toLowerCase();
            return name.contains(q) || type.contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search for a place...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final poi = suggestions[index];
                return ListTile(
                  leading: _getIconForPoi(poi),
                  title: Text(poi['name'] ?? 'Unnamed'),
                  subtitle: Text(poi['type'] ?? 'Unknown'),
                  onTap: () {
                    Navigator.of(context).pop(poi);
                  },
                );
              },
            ),
    );
  }
}
