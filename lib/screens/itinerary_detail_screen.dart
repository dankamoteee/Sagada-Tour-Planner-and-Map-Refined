// lib/screens/itinerary_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'event_editor_screen.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ⭐️ ADD THIS IMPORT

class ItineraryDetailScreen extends StatefulWidget {
  final String itineraryId;
  final String itineraryName;

  const ItineraryDetailScreen({
    super.key,
    required this.itineraryId,
    required this.itineraryName,
  });

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  // --- Your _deleteEvent, _onReorder, and _deleteEntireItinerary functions
  // --- are all perfect. No changes needed to them. ---

  Future<void> _deleteEvent(String eventId) async {
    // ... (your existing code)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .doc(widget.itineraryId)
        .collection('events')
        .doc(eventId)
        .delete();
  }

  Future<void> _onReorder(
    List<DocumentSnapshot> events,
    int oldIndex,
    int newIndex,
  ) async {
    // ... (your existing code)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = events.removeAt(oldIndex);
    events.insert(newIndex, item);
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < events.length; i++) {
      final docRef = events[i].reference;
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }

  Future<void> _deleteEntireItinerary() async {
    // ... (your existing code)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Itinerary?'),
        content: Text(
          'Are you sure you want to permanently delete "${widget.itineraryName}" and all of its events? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (didConfirm == true) {
      showDialog(
        context: context,
        builder: (context) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      try {
        final batch = FirebaseFirestore.instance.batch();
        final itineraryRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('itineraries')
            .doc(widget.itineraryId);

        final eventsSnapshot = await itineraryRef.collection('events').get();
        for (final doc in eventsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(itineraryRef);
        await batch.commit();

        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          Navigator.pop(
            context,
            'Successfully deleted "${widget.itineraryName}"!',
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete itinerary: $e')),
          );
        }
      }
    }
  }

  // --- ⭐️ NEW HELPER WIDGET ⭐️ ---
  /// Builds the new visual card for each event
  Widget _buildEventItem(DocumentSnapshot eventDoc) {
    final event = eventDoc.data() as Map<String, dynamic>;
    final eventTime = (event['eventTime'] as Timestamp).toDate();
    final notes = event['notes'] as String?;
    final poiId = event['destinationPoiId'] as String?;

    // --- Case 1: This is a "Custom Event" (no POI linked) ---
    if (poiId == null) {
      return Dismissible(
        key: ValueKey(eventDoc.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteEvent(eventDoc.id),
        background: _buildDeleteBackground(),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.jm().format(eventTime),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            title: Text(
              event['destinationName'] ?? 'Custom Event',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: notes != null && notes.isNotEmpty
                ? Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: const Icon(Icons.drag_handle, color: Colors.grey),
            onTap: () => _navigateToEditor(eventDoc: eventDoc),
          ),
        ),
      );
    }

    // --- Case 2: This is a POI Event (fetch POI data) ---
    return Dismissible(
      key: ValueKey(eventDoc.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteEvent(eventDoc.id),
      background: _buildDeleteBackground(),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('POIs').doc(poiId).get(),
        builder: (context, poiSnapshot) {
          // --- Build the Card with POI data ---
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              // --- 1. POI IMAGE (Leading) ---
              leading: _buildPoiImage(poiSnapshot),

              // --- 2. POI NAME (Title) ---
              title: Text(
                poiSnapshot.hasData
                    ? (poiSnapshot.data!['name'] ?? 'Loading...')
                    : 'Loading...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              // --- 3. TIME AND NOTES (Subtitle) ---
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.jm().format(eventTime),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
              trailing: const Icon(Icons.drag_handle, color: Colors.grey),
              onTap: () => _navigateToEditor(
                eventDoc: eventDoc,
                poiData: poiSnapshot.hasData
                    ? poiSnapshot.data!.data() as Map<String, dynamic>
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // --- ⭐️ NEW HELPER FOR THE IMAGE ⭐️ ---
  Widget _buildPoiImage(AsyncSnapshot<DocumentSnapshot> poiSnapshot) {
    if (!poiSnapshot.hasData || poiSnapshot.data?.data() == null) {
      return Container(
        width: 60,
        height: 60,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final poiData = poiSnapshot.data!.data() as Map<String, dynamic>;

    // Use the same robust logic from poi_card.dart
    final String? primaryImage = poiData['primaryImage'] as String?;
    final List<dynamic>? imagesList = poiData['images'] as List<dynamic>?;
    final String? legacyImageUrl = poiData['imageUrl'] as String?;

    String? displayImageUrl;
    if (primaryImage != null && primaryImage.isNotEmpty) {
      displayImageUrl = primaryImage;
    } else if (imagesList != null && imagesList.isNotEmpty) {
      displayImageUrl = imagesList[0] as String?;
    } else if (legacyImageUrl != null && legacyImageUrl.isNotEmpty) {
      displayImageUrl = legacyImageUrl;
    }

    return Container(
      width: 60,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: (displayImageUrl != null && displayImageUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: displayImageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey)),
              )
            : Container(
                color: Colors.grey[200],
                child: const Icon(Icons.location_on, color: Colors.grey),
              ),
      ),
    );
  }

  // --- ⭐️ NEW HELPER FOR NAVIGATION ⭐️ ---
  /// Navigates to the editor, passing both event and POI data
  Future<void> _navigateToEditor({
    DocumentSnapshot? eventDoc,
    Map<String, dynamic>? poiData,
  }) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventEditorScreen(
          itineraryId: widget.itineraryId,
          eventDoc: eventDoc,
          // We pass initial POI data to pre-fill the editor
          initialPoiData: poiData,
        ),
      ),
    );

    if (result is String && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor:
              result.contains('deleted') ? Colors.red : Colors.green,
        ),
      );
    }
  }

  // --- ⭐️ NEW HELPER FOR DISMISSIBLE ⭐️ ---
  Widget _buildDeleteBackground() {
    return Container(
      color: Colors.red.shade400,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20.0),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: const Icon(
        Icons.delete_outline,
        color: Colors.white,
      ),
    );
  }

  // --- ⭐️ YOUR MAIN BUILD METHOD, NOW CLEANER ⭐️ ---
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itineraryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: _deleteEntireItinerary,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('itineraries')
            .doc(widget.itineraryId)
            .collection('events')
            .orderBy('eventTime')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No plans yet. Add your first event!'),
            );
          }

          final Map<DateTime, List<DocumentSnapshot>> eventsByDate = {};
          for (var doc in snapshot.data!.docs) {
            final eventTime = (doc['eventTime'] as Timestamp).toDate();
            final dateKey = DateTime(
              eventTime.year,
              eventTime.month,
              eventTime.day,
            );

            if (!eventsByDate.containsKey(dateKey)) {
              eventsByDate[dateKey] = [];
            }
            eventsByDate[dateKey]!.add(doc);
          }

          final sortedDates = eventsByDate.keys.toList()..sort();

          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final events = eventsByDate[date]!;
              final dayNumber = index + 1;

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 12.0,
                          ),
                          child: Text(
                            'Day $dayNumber - ${DateFormat.yMMMEd().format(date)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // "Show on Map" Button
                        TextButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Show on Map'),
                          onPressed: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            final List<GeoPoint> coordinates = [];
                            for (final eventDoc in events) {
                              final event =
                                  eventDoc.data() as Map<String, dynamic>;
                              final poiId =
                                  event['destinationPoiId'] as String?;

                              if (poiId != null) {
                                final poiDoc = await FirebaseFirestore.instance
                                    .collection('POIs')
                                    .doc(poiId)
                                    .get();
                                if (poiDoc.exists) {
                                  final poiData = poiDoc.data()!;

                                  // This is the safe parsing logic
                                  final dynamic coordsData =
                                      poiData['coordinates'];
                                  GeoPoint? coords;

                                  if (coordsData is GeoPoint) {
                                    coords = coordsData;
                                  } else if (coordsData is Map) {
                                    coords = GeoPoint(
                                      coordsData['latitude'] ?? 0.0,
                                      coordsData['longitude'] ?? 0.0,
                                    );
                                  }

                                  if (coords != null) {
                                    coordinates.add(coords);
                                  }
                                }
                              }
                            }

                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted) {
                              Navigator.pop(context, coordinates);
                            }
                          },
                        ),
                      ],
                    ),

                    // Reorderable list for the day's events
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) =>
                          _onReorder(events, oldIndex, newIndex),
                      // --- HERE IS THE BIG CHANGE ---
                      // We map each eventDoc to our new helper widget
                      children: events
                          .map((eventDoc) => _buildEventItem(eventDoc))
                          .toList(),
                      // --- END OF CHANGE ---
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Use the new navigation helper
          _navigateToEditor();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
