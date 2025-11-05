// In lib/services/poi_search_delegate.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/poi_model.dart';

class POISearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final LatLng? userLocation;

  POISearchDelegate({this.userLocation});

  // --- 1. NEW: HELPER TO FETCH NEARBY POIS ---
  /// Fetches all POIs and returns a sorted list of those within 5km.
  Future<List<Poi>> _fetchNearbyPois() async {
    if (userLocation == null) return []; // No location, no nearby

    final snapshot = await FirebaseFirestore.instance.collection('POIs').get();
    List<Poi> nearbyPois = [];

    for (var doc in snapshot.docs) {
      final poi = Poi.fromFirestore(doc);
      final double distance = Geolocator.distanceBetween(
        userLocation!.latitude,
        userLocation!.longitude,
        poi.coordinates.latitude,
        poi.coordinates.longitude,
      );

      if (distance <= 5000) {
        // 5km radius
        poi.distance = distance; // Save distance to the model
        nearbyPois.add(poi);
      }
    }

    // Sort by distance, closest first
    nearbyPois.sort((a, b) => a.distance!.compareTo(b.distance!));
    return nearbyPois;
  }

  // --- 2. NEW: HELPER TO FETCH POPULAR POIS ---
  /// Fetches POIs where 'recommended' is true.
  Future<List<Poi>> _fetchPopularPois() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('POIs')
          .where('recommended', isEqualTo: true) // Assumes you have this field
          .limit(10) // Get top 10
          .get();

      return snapshot.docs.map((doc) => Poi.fromFirestore(doc)).toList();
    } catch (e) {
      print(
          "Error fetching popular POIs (is 'recommended' field indexed?): $e");
      return []; // Return empty on error
    }
  }

  // --- 3. NEW: HELPER TO BUILD SECTION HEADERS ---
  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // --- 4. NEW: HELPER TO BUILD A SUGGESTION TILE (FOR NEARBY/POPULAR) ---
  ListTile _buildSuggestionTile(Poi poi, BuildContext context) {
    String subtitle;
    if (poi.distance != null) {
      // If it's a nearby POI, show distance
      final distanceKm = (poi.distance! / 1000).toStringAsFixed(1);
      subtitle = "${poi.type} • $distanceKm km away";
    } else {
      // If it's a popular POI, just show type
      subtitle = poi.type;
    }

    return ListTile(
      leading: _getIconForType(poi.type),
      title: Text(poi.name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      onTap: () {
        close(context, poi.toMap());
      },
    );
  }

  // --- 5. NEW: HELPER TO BUILD A SEARCH RESULT TILE (WITH HIGHLIGHTING) ---
  ListTile _buildSearchTile(Poi poi, BuildContext context) {
    return ListTile(
      leading: _getIconForType(poi.type),
      title: _highlightMatch(poi.name, query, context), // Use highlighter
      subtitle: Text(poi.type),
      onTap: () {
        close(context, poi.toMap());
      },
    );
  }

  // --- 6. UPDATED: buildSuggestions is now a router ---
  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      // If query is empty, show grouped suggestions
      return _buildGroupedSuggestions(context);
    } else {
      // If user is typing, show text-based results
      return _buildTextSearchResults(context);
    }
  }

  // --- 7. NEW: WIDGET TO BUILD THE GROUPS ---
  Widget _buildGroupedSuggestions(BuildContext context) {
    // If we have no location, just show Popular
    if (userLocation == null) {
      return FutureBuilder<List<Poi>>(
        future: _fetchPopularPois(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No popular places found.'));
          }

          final popularPois = snapshot.data!;
          return ListView(
            children: [
              _buildSectionHeader(
                  "Popular in Sagada", context), // 👈 PASS CONTEXT
              ...popularPois.map((poi) => _buildSuggestionTile(poi, context)),
            ],
          );
        },
      );
    }

    // We have a location, so fetch BOTH lists at the same time
    return FutureBuilder<List<List<Poi>>>(
      future: Future.wait([
        _fetchNearbyPois(),
        _fetchPopularPois(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('Could not load suggestions.'));
        }

        final nearbyPois = snapshot.data![0];
        final popularPois = snapshot.data![1];

        // Build a single ListView with all sections
        return ListView(
          children: [
            // --- Nearby Section ---
            _buildSectionHeader("Nearby", context), // 👈 PASS CONTEXT
            if (nearbyPois.isEmpty)
              const ListTile(
                  title: Text('No nearby places found within 5km.',
                      style: TextStyle(color: Colors.grey))),
            ...nearbyPois.map((poi) => _buildSuggestionTile(poi, context)),

            // --- Popular Section ---
            _buildSectionHeader(
                "Popular in Sagada", context), // 👈 PASS CONTEXT
            if (popularPois.isEmpty)
              const ListTile(
                  title: Text('No recommended places found.',
                      style: TextStyle(color: Colors.grey))),
            ...popularPois.map((poi) => _buildSuggestionTile(poi, context)),
          ],
        );
      },
    );
  }

  // --- 8. UPDATED: This is your old search logic, now in its own function ---
  Widget _buildTextSearchResults(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('POIs').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPois =
            snapshot.data!.docs.map((doc) => Poi.fromFirestore(doc)).toList();

        final suggestions = allPois.where((poi) {
          final name = poi.name.toLowerCase();
          final type = poi.type.toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || type.contains(q);
        }).toList();

        if (suggestions.isEmpty) {
          return const Center(
            child: Text(
              'No places found.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final poi = suggestions[index];
            return _buildSearchTile(poi, context); // Use the search tile
          },
        );
      },
    );
  }

  // --- (Your other helper methods are unchanged) ---
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  Widget _getIconForType(String type) {
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

  Widget _highlightMatch(String text, String q, BuildContext context) {
    if (q.isEmpty) {
      return Text(text, style: Theme.of(context).textTheme.titleMedium);
    }
    final lowerText = text.toLowerCase();
    final lowerQ = q.toLowerCase();
    if (!lowerText.contains(lowerQ)) {
      return Text(text, style: Theme.of(context).textTheme.titleMedium);
    }
    final start = lowerText.indexOf(lowerQ);
    final end = start + q.length;
    final defaultStyle =
        Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    final highlightStyle = defaultStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
    );
    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(text: text.substring(start, end), style: highlightStyle),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
