// In lib/services/poi_search_delegate.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/poi_model.dart';

// --- ⭐️ START OF FIX ⭐️ ---
// This is a private, safe parser that will be used *only* by the search delegate.
// It will not crash if data is in the wrong format.
Poi _safePoiFromFirestore(DocumentSnapshot doc) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

  // Safe Coordinate Parsing
  dynamic coordsData = data['coordinates'];
  GeoPoint coordinates;
  if (coordsData is GeoPoint) {
    coordinates = coordsData;
  } else if (coordsData is Map) {
    coordinates = GeoPoint(
      coordsData['latitude'] ?? 0.0,
      coordsData['longitude'] ?? 0.0,
    );
  } else {
    coordinates = const GeoPoint(0, 0);
  }

  // Safe List<String> Parsing for Images
  List<String> images = [];
  if (data['images'] is List) {
    images = List<String>.from(
        (data['images'] as List).map((item) => item.toString()));
  }

  // Safe Map Parsing for Entrance Fee (this fixes the crash)
  Map<String, dynamic>? entranceFee;
  if (data['entranceFee'] is Map) {
    entranceFee = data['entranceFee'] as Map<String, dynamic>;
  }
  // If entranceFee is a List or String, it will just be null (no crash)

  return Poi(
    id: doc.id,
    name: data['name'] ?? 'Unnamed',
    description: data['description'] ?? '',
    type: data['type'] ?? 'Unknown',
    coordinates: coordinates,
    primaryImage: data['primaryImage'] as String?,
    images: images,
    legacyImageUrl: data['imageUrl'] as String?,
    openingHours: data['openingHours'] as String?,
    contactNumber: data['contactNumber'] as String?,
    status: data['status'] as String?,
    entranceFee: entranceFee, // Use the safe variable
    guideRequired: data['guideRequired'] as bool?,
  );
}
// --- ⭐️ END OF FIX ⭐️ ---

class POISearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final LatLng? userLocation;

  POISearchDelegate({this.userLocation});

  // --- 1. HELPER TO FETCH NEARBY POIS ---
  Future<List<Poi>> _fetchNearbyPois() async {
    if (userLocation == null) return [];

    final snapshot = await FirebaseFirestore.instance.collection('POIs').get();
    List<Poi> nearbyPois = [];

    for (var doc in snapshot.docs) {
      // ⭐️ Use the safe parser
      final poi = _safePoiFromFirestore(doc);

      final double distance = Geolocator.distanceBetween(
        userLocation!.latitude,
        userLocation!.longitude,
        poi.coordinates.latitude,
        poi.coordinates.longitude,
      );

      if (distance <= 5000) {
        poi.distance = distance;
        nearbyPois.add(poi);
      }
    }

    nearbyPois.sort((a, b) => a.distance!.compareTo(b.distance!));
    return nearbyPois;
  }

  // --- 2. ⭐️ REPLACED HELPER: FETCH RANDOM POIS ⭐️ ---
  Future<List<Poi>> _fetchRandomPois() async {
    try {
      final randomId = _generateRandomId();
      final snapshot = await FirebaseFirestore.instance
          .collection('POIs')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: randomId)
          .limit(10)
          .get();

      if (snapshot.docs.length < 10) {
        final snapshot2 = await FirebaseFirestore.instance
            .collection('POIs')
            .where(FieldPath.documentId, isLessThan: randomId)
            .limit(10 - snapshot.docs.length)
            .get();

        return [
          // ⭐️ Use the safe parser
          ...snapshot.docs.map((doc) => _safePoiFromFirestore(doc)),
          ...snapshot2.docs.map((doc) => _safePoiFromFirestore(doc)),
        ];
      }

      // ⭐️ Use the safe parser
      return snapshot.docs.map((doc) => _safePoiFromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching random POIs: $e");
      return [];
    }
  }

  // --- 3. ⭐️ NEW HELPER: RANDOM ID GENERATOR ⭐️ ---
  String _generateRandomId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = math.Random();
    return String.fromCharCodes(Iterable.generate(
        20, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // --- 4. ⭐️ FIXED HELPER: BUILD SECTION HEADERS ⭐️ ---
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

  // --- 5. HELPER TO BUILD A SUGGESTION TILE (Unchanged) ---
  ListTile _buildSuggestionTile(Poi poi, BuildContext context) {
    String subtitle;
    if (poi.distance != null) {
      final distanceKm = (poi.distance! / 1000).toStringAsFixed(1);
      subtitle = "${poi.type} • $distanceKm km away";
    } else {
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
      return _buildGroupedSuggestions(context);
    } else {
      return _buildTextSearchResults(context);
    }
  }

  // --- 8. ⭐️ UPDATED: WIDGET TO BUILD THE GROUPS ⭐️ ---
  Widget _buildGroupedSuggestions(BuildContext context) {
    if (userLocation == null) {
      return FutureBuilder<List<Poi>>(
        future: _fetchRandomPois(),
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
              _buildSectionHeader("Random Suggestions", context),
              ...randomPois.map((poi) => _buildSuggestionTile(poi, context)),
            ],
          );
        },
      );
    }

    return FutureBuilder<List<List<Poi>>>(
      future: Future.wait([
        _fetchNearbyPois(),
        _fetchRandomPois(),
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

        return ListView(
          children: [
            _buildSectionHeader("Nearby", context),
            if (nearbyPois.isEmpty)
              const ListTile(
                  title: Text('No nearby places found within 5km.',
                      style: TextStyle(color: Colors.grey))),
            ...nearbyPois.map((poi) => _buildSuggestionTile(poi, context)),
            _buildSectionHeader("Random Suggestions", context),
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

  // --- 9. UPDATED: TEXT SEARCH RESULTS ---
  Widget _buildTextSearchResults(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('POIs').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPois =
            // ⭐️ Use the safe parser
            snapshot.data!.docs
                .map((doc) => _safePoiFromFirestore(doc))
                .toList();

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
            return _buildSearchTile(poi, context);
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
    // ⭐️ FIX: Define a stable text style (Body Medium is standard for lists)
    final TextStyle baseStyle = Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, color: Colors.black87);

    final TextStyle highlightStyle = baseStyle.copyWith(
      color: Theme.of(context).primaryColor,
      fontWeight: FontWeight.bold,
    );

    if (q.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQ = q.toLowerCase();

    if (!lowerText.contains(lowerQ)) {
      return Text(text, style: baseStyle);
    }

    final start = lowerText.indexOf(lowerQ);
    final end = start + q.length;

    return RichText(
      text: TextSpan(
        style: baseStyle, // Apply base style to the whole span
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(text: text.substring(start, end), style: highlightStyle),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
