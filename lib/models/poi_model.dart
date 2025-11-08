// In lib/models/poi_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Poi {
  final String id;
  final String name;
  final String description;
  final String type;
  final GeoPoint coordinates;

  // New Image System (from Storage)
  final String? primaryImage; // For cards/lists
  final List<String> images; // For the gallery

  // Reverted to simple fields
  final String? openingHours;
  final String? contactNumber;
  final String? status; // e.g., "Open", "Closed"

  // New Simplified Map
  final Map<String, dynamic>? entranceFee; // Will hold 'adult', 'child'

  // Original field
  final bool? guideRequired;

  // Local-only field
  double? distance;

  Poi({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.coordinates,
    required this.images,
    this.primaryImage,
    this.openingHours,
    this.contactNumber,
    this.status,
    this.entranceFee,
    this.guideRequired,
    this.distance,
  });

  // Factory constructor to create a Poi instance from a Firestore document
  factory Poi.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // --- Safe Coordinate Parsing ---
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

    // --- Safe List<String> Parsing for Images ---
    List<String> images = [];
    if (data['images'] is List) {
      images = List<String>.from(
          (data['images'] as List).map((item) => item.toString()));
    }

    return Poi(
      id: doc.id,
      name: data['name'] ?? 'Unnamed',
      description: data['description'] ?? '',
      type: data['type'] ?? 'Unknown',
      coordinates: coordinates,
      primaryImage: data['primaryImage'] as String?,
      images: images,
      openingHours: data['openingHours'] as String?, // Reverted to String
      contactNumber: data['contactNumber'] as String?, // Reverted to String
      status: data['status'] as String?, // Reverted to String
      entranceFee:
          data['entranceFee'] as Map<String, dynamic>?, // Simplified Map
      guideRequired: data['guideRequired'] as bool?,
    );
  }

  // A method to convert our Poi object back to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'coordinates': coordinates,
      'primaryImage': primaryImage,
      'images': images,
      'openingHours': openingHours,
      'contactNumber': contactNumber,
      'status': status,
      'entranceFee': entranceFee,
      'guideRequired': guideRequired,
      // These are not part of the DB structure
      'lat': coordinates.latitude,
      'lng': coordinates.longitude,
    };
  }
}
