import 'package:cloud_firestore/cloud_firestore.dart';

class TourGuide {
  final String id;
  final String name;
  final String org;
  final String phone;
  final String imageUrl;
  final List<String> areas;

  TourGuide({
    this.id = '',
    required this.name,
    required this.org,
    required this.phone,
    required this.imageUrl,
    required this.areas,
  });

  // Factory to create a TourGuide from a Firestore Document
  factory TourGuide.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return TourGuide(
      id: doc.id,
      name: data['name'] ?? '',
      org: data['org'] ?? '',
      phone: data['phone'] ?? '',
      imageUrl: data['image'] ?? '', // Note: Firestore field is 'image'
      areas: List<String>.from(
        data['area'] is List ? data['area'] : [data['area'] ?? ''],
      ),
    );
  }

  // Method to convert TourGuide to Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'org': org,
      'phone': phone,
      'image': imageUrl, // Note: Firestore field is 'image'
      'area': areas,
    };
  }
}
