// In lib/services/poi_search_delegate.dart

import 'dart:math' as math; // 👈 ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/poi_model.dart';

class POISearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final LatLng? userLocation;

  POISearchDelegate({this.userLocation});

  // --- 1. HELPER TO FETCH NEARBY POIS (Unchanged) ---
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

  // --- 2. ⭐️ REPLACED HELPER: FETCH RANDOM POIS ⭐️ ---
  /// Fetches a random selection of POIs.
  Future<List<Poi>> _fetchRandomPois() async {
    try {
      // Generate a random 20-char ID to start the query from
      final randomId = _generateRandomId();

      final snapshot = await FirebaseFirestore.instance
          .collection('POIs')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: randomId)
          .limit(10) // Get 10 documents starting from that random point
          .get();

      // If we didn't get enough, try again by querying backwards
      // This makes sure we always get results, even if randomId is near the end
      if (snapshot.docs.length < 10) {
        final snapshot2 = await FirebaseFirestore.instance
            .collection('POIs')
            .where(FieldPath.documentId, isLessThan: randomId)
            .limit(10 - snapshot.docs.length)
            .get();

        // Combine the two lists
        return [
          ...snapshot.docs.map((doc) => Poi.fromFirestore(doc)),
          ...snapshot2.docs.map((doc) => Poi.fromFirestore(doc)),
        ];
      }

      return snapshot.docs.map((doc) => Poi.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching random POIs: $e");
      return []; // Return empty on error
    }
  }

  // --- 3. ⭐️ NEW HELPER: RANDOM ID GENERATOR ⭐️ ---
  /// Generates a 20-character random ID for Firestore queries.
  String _generateRandomId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = math.Random();
    return String.fromCharCodes(Iterable.generate(
        20, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // --- 4. ⭐️ FIXED HELPER: BUILD SECTION HEADERS ⭐️ ---
  Widget _buildSectionHeader(String title, BuildContext context) {
    // 👈 Added context
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor, // 👈 Now works
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // --- 5. HELPER TO BUILD A SUGGESTION TILE (Unchanged) ---
  ListTile _buildSuggestionTile(Poi poi, BuildContext context) {
    String subtitle;
    if (poi.distance != null) {
      // If it's a nearby POI, show distance
      final distanceKm = (poi.distance! / 1000).toStringAsFixed(1);
      subtitle = "${poi.type} • $distanceKm km away";
    } else {
      // If it's a random POI, just show type
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

  // --- 6. HELPER TO BUILD A SEARCH RESULT TILE (Unchanged) ---
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

  // --- 7. UPDATED: buildSuggestions (Unchanged) ---
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

  // --- 8. ⭐️ UPDATED: WIDGET TO BUILD THE GROUPS ⭐️ ---
  Widget _buildGroupedSuggestions(BuildContext context) {
    // If we have no location, just show Random
    if (userLocation == null) {
      return FutureBuilder<List<Poi>>(
        future: _fetchRandomPois(), // 👈 Call random
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No places found.'));
          }

          final randomPois = snapshot.data!;
          return ListView(
            children: [
              _buildSectionHeader("Random Suggestions", context), // 👈 Rename
              ...randomPois.map((poi) => _buildSuggestionTile(poi, context)),
            ],
          );
        },
      );
    }

    // We have a location, so fetch BOTH lists at the same time
    return FutureBuilder<List<List<Poi>>>(
      future: Future.wait([
        _fetchNearbyPois(),
        _fetchRandomPois(), // 👈 Call random
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('Could not load suggestions.'));
        }

        final nearbyPois = snapshot.data![0];
        final randomPois = snapshot.data![1];

        // Build a single ListView with all sections
        return ListView(
          children: [
            // --- Nearby Section ---
            _buildSectionHeader("Nearby", context), // 👈 Pass context
            if (nearbyPois.isEmpty)
              const ListTile(
                  title: Text('No nearby places found within 5km.',
                      style: TextStyle(color: Colors.grey))),
            ...nearbyPois.map((poi) => _buildSuggestionTile(poi, context)),

            // --- Random Section ---
            _buildSectionHeader("Random Suggestions", context), // 👈 Rename
            if (randomPois.isEmpty)
              const ListTile(
                  title: Text('No places found.',
                      style: TextStyle(color: Colors.grey))),
            ...randomPois.map((poi) => _buildSuggestionTile(poi, context)),
          ],
        );
      },
    );
  }

  // --- 9. UPDATED: TEXT SEARCH RESULTS (Unchanged) ---
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
