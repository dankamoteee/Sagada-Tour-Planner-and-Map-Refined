import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tour_guide_model.dart';

class UserDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves a POI to the user's "Recently Viewed" history.
  /// Handles robust image selection (primary vs legacy) and limits list size.
  Future<void> saveToRecentlyViewed({
    required String userId,
    required Map<String, dynamic> poiData,
  }) async {
    final String poiId = poiData['id'];
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('recentlyViewed')
        .doc(poiId);

    // Robust Image Logic
    final String? primaryImage = poiData['primaryImage'] as String?;
    final List<dynamic>? imagesList = poiData['images'] as List<dynamic>?;
    final String? legacyImageUrl = poiData['imageUrl'] as String?;

    String? recentImageUrl;
    if (primaryImage != null && primaryImage.isNotEmpty) {
      recentImageUrl = primaryImage;
    } else if (imagesList != null && imagesList.isNotEmpty) {
      recentImageUrl = imagesList[0] as String?;
    } else if (legacyImageUrl != null && legacyImageUrl.isNotEmpty) {
      recentImageUrl = legacyImageUrl;
    }

    await docRef.set({
      'poiId': poiId,
      'viewedAt': FieldValue.serverTimestamp(),
      'name': poiData['name'],
      'imageUrl': recentImageUrl ?? '',
    });

    // Limit history to 20 items to save space
    final query = _firestore
        .collection('users')
        .doc(userId)
        .collection('recentlyViewed')
        .orderBy('viewedAt', descending: true)
        .limit(20);

    final snapshot = await query.get();
    if (snapshot.docs.length == 20) {
      final lastVisible = snapshot.docs.last;
      final olderItemsQuery = _firestore
          .collection('users')
          .doc(userId)
          .collection('recentlyViewed')
          .where('viewedAt', isLessThan: lastVisible['viewedAt']);

      final olderItems = await olderItemsQuery.get();
      for (var doc in olderItems.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Fetches the active Tour Guide details for a specific itinerary.
  Future<TourGuide?> fetchActiveGuide({
    required String userId,
    required String itineraryId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('itineraries')
          .doc(itineraryId)
          .get();

      if (doc.exists && doc.data()!.containsKey('guideId')) {
        final String guideId = doc.data()!['guideId'];
        if (guideId.isNotEmpty) {
          final guideDoc =
              await _firestore.collection('tourGuides').doc(guideId).get();
          if (guideDoc.exists) {
            return TourGuide.fromFirestore(guideDoc);
          }
        }
      }
    } catch (e) {
      // Handle or log error
      print("Error fetching guide: $e");
    }
    return null;
  }

  /// Clears the active itinerary from local storage.
  Future<void> clearActiveItinerary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeItineraryId');
    await prefs.remove('activeItineraryName');
  }

  /// Gets a stream of upcoming events for the active itinerary.
  Stream<QuerySnapshot>? getActiveItineraryStream({
    required String userId,
    required String itineraryId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('itineraries')
        .doc(itineraryId)
        .collection('events')
        .where('eventTime', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('eventTime')
        .snapshots();
  }

  /// Fetches a list of user's itineraries for the selector dialog
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getUserItineraries(
      String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('itineraries')
        .get();
    return snapshot.docs;
  }
}
