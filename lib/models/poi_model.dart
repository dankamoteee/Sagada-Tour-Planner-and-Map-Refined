// In lib/models/poi_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Poi {
  final String id;
  final String name;
  final String description;
  final String type;
  final GeoPoint coordinates;
  final List<String> images;
  final String? imageUrl;
  final String? status; // 👈 ADD THIS
  final bool? guideRequired; // 👈 ADD THIS
  double? distance; // 👈 ADD THIS FIELD

  Poi({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.coordinates,
    required this.images,
    this.imageUrl,
    this.status, // 👈 ADD THIS
    this.guideRequired, // 👈 ADD THIS
    this.distance,
  });

  // Factory constructor to create a Poi instance from a Firestore document
  // Factory constructor to create a Poi instance from a Firestore document
  factory Poi.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // --- START OF FIX ---
    dynamic coordsData = data['coordinates'];
    GeoPoint coordinates;

    if (coordsData is GeoPoint) {
      // It's already a GeoPoint, just use it.
      coordinates = coordsData;
    } else if (coordsData is Map) {
      // It's a Map, so extract lat/lng.
      coordinates = GeoPoint(
        coordsData['latitude'] ?? 0.0,
        coordsData['longitude'] ?? 0.0,
      );
    } else {
      // It's null or some other type, use a default.
      coordinates = const GeoPoint(0, 0);
    }
    // --- END OF FIX ---

    // --- START OF 2ND FIX (for the 'images' field) ---
    // Let's fix the 'images' field while we're here, just in case.
    // This will prevent the same crash we fixed earlier.
    List<String> images = [];
    if (data['images'] is List) {
      images = List<String>.from(data['images']);
    }
    // --- END OF 2ND FIX ---

    return Poi(
      id: doc.id,
      name: data['name'] ?? 'Unnamed',
      description: data['description'] ?? '',
      type: data['type'] ?? 'Unknown',
      coordinates: coordinates, // Use the safe coordinates
      images: images, // Use the safe images list
      imageUrl: data['imageUrl'],
      status:
          data['status'], // 👈 ADD THIS (will be null if field doesn't exist)
      guideRequired: data[
          'guideRequired'], // 👈 ADD THIS (will be null if field doesn't exist)
    );
  }
  // A method to convert our Poi object back to a Map, which is useful
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'coordinates': coordinates,
      'images': images,
      'imageUrl': imageUrl,
      'lat': coordinates.latitude,
      'lng': coordinates.longitude,
      'status': status, // 👈 ADD THIS
      'guideRequired': guideRequired, // 👈 ADD THIS
    };
  }
}
