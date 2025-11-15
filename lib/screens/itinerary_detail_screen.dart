// lib/screens/itinerary_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'event_editor_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dart:async';
import 'package:provider/provider.dart';

import 'event_journal_screen.dart'; // ⭐️ --- ADD THIS NEW IMPORT --- ⭐️

class ItineraryDetailScreen extends StatefulWidget {
  // ... (no changes here) ...
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

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen>
    with TickerProviderStateMixin {
  // ... (no changes to state variables) ...
  Timer? _liveTimer;
  String? _currentEventId;
  bool _isToday = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _liveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _findCurrentEvent();
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
        dateA.month == dateB.month &&
        dateA.day == dateB.day;
  }

  void _findCurrentEvent() {
    final now = DateTime.now();

    final streamProvider = context.read<Stream<QuerySnapshot>?>();
    if (streamProvider == null) return;

    streamProvider.first.then((snapshot) {
      if (!mounted || snapshot.docs.isEmpty) return;

      final eventsForToday = snapshot.docs.where((doc) {
        final eventTime = (doc['eventTime'] as Timestamp).toDate();
        return _isSameDay(eventTime, now);
      }).toList();

      if (eventsForToday.isEmpty) {
        setState(() {
          _isToday = false;
          _currentEventId = null;
        });
        return;
      }

      DocumentSnapshot? nextEvent;
      for (final event in eventsForToday) {
        final eventTime = (event['eventTime'] as Timestamp).toDate();
        final eventEnd = eventTime.add(const Duration(hours: 3));

        if (now.isAfter(eventTime) && now.isBefore(eventEnd)) {
          nextEvent = event;
          break;
        }
        if (eventTime.isAfter(now)) {
          nextEvent = event;
          break;
        }
      }

      nextEvent ??= eventsForToday.last;

      if (mounted) {
        setState(() {
          _isToday = true;
          _currentEventId = nextEvent?.id;
        });
      }
    });
  }

  Future<void> _deleteEvent(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final itineraryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .doc(widget.itineraryId);

    await itineraryRef.collection('events').doc(eventId).delete();

    final eventsQuery = itineraryRef
        .collection('events')
        .orderBy('eventTime', descending: true)
        .limit(1);

    final snapshot = await eventsQuery.get();

    Timestamp? newLastEventDate;
    if (snapshot.docs.isNotEmpty) {
      newLastEventDate = snapshot.docs.first.data()['eventTime'] as Timestamp?;
    }

    await itineraryRef.update({
      'totalEvents': FieldValue.increment(-1),
      'lastEventDate': newLastEventDate,
    });
  }

  Future<void> _deleteEntireItinerary() async {
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

  Future<String?> _getTravelDuration(LatLng origin, LatLng destination) async {
    const String apiKey = "AIzaSyCp73OfWNg7pGMFCe6QVdSCkyPBhwof9dI";
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["routes"].isNotEmpty) {
          final leg = data["routes"][0]["legs"][0];
          return leg["duration"]["text"] as String?;
        }
      }
    } catch (e) {
      print("Error fetching travel duration: $e");
    }
    return null;
  }

  Future<void> _navigateToJournal(DocumentSnapshot eventDoc) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventJournalScreen(
          eventDoc: eventDoc,
          itineraryId: widget.itineraryId,
        ),
      ),
    );

    if (result is String && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ⭐️ --- MODIFIED _buildEventItem HELPER --- ⭐️
  Widget _buildEventItem(
    DocumentSnapshot eventDoc, {
    required bool isCurrent,
  }) {
    final event = eventDoc.data() as Map<String, dynamic>;
    final eventTime = (event['eventTime'] as Timestamp).toDate();
    final notes = event['notes'] as String?;
    final poiId = event['destinationPoiId'] as String?;

    // --- Journal Logic ---
    final bool hasJournal = event['hasJournalEntry'] ?? false;
    final bool isPast =
        eventTime.isBefore(DateTime.now().subtract(const Duration(hours: 1)));

    // ⭐️ --- START OF REVAMPED UI WIDGET --- ⭐️
    Widget? journalWidget;
    if (isPast) {
      journalWidget = Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: ActionChip(
          onPressed: () => _navigateToJournal(eventDoc),
          avatar: Icon(
            hasJournal ? Icons.photo_album_rounded : Icons.add_comment_rounded,
            size: 16,
            color: hasJournal
                ? Theme.of(context).primaryColor
                : Colors.grey.shade700,
          ),
          label: Text(hasJournal ? 'View Journal' : 'Add Journal'),
          backgroundColor: hasJournal
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey.shade200,
        ),
      );
    }
    // ⭐️ --- END OF REVAMPED UI WIDGET --- ⭐️

    Widget? highlightIcon;
    Color cardColor = Colors.white;

    if (isCurrent) {
      cardColor = Colors.blue.shade50;
      highlightIcon = FadeTransition(
        opacity: _pulseController,
        child: Icon(
          Icons.watch_later_rounded,
          color: Theme.of(context).primaryColor,
          size: 20,
        ),
      );
    }

    // --- Case 1: Custom Event ---
    if (poiId == null) {
      return Dismissible(
        key: ValueKey(eventDoc.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteEvent(eventDoc.id),
        background: _buildDeleteBackground(),
        child: Card(
          color: cardColor,
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notes != null && notes.isNotEmpty)
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (journalWidget != null) journalWidget, // ⭐️ ADDED THIS
              ],
            ),
            trailing: highlightIcon,
            onTap: () => _navigateToEditor(eventDoc: eventDoc),
          ),
        ),
      );
    }

    // --- Case 2: POI Event ---
    return Dismissible(
      key: ValueKey(eventDoc.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteEvent(eventDoc.id),
      background: _buildDeleteBackground(),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('POIs').doc(poiId).get(),
        builder: (context, poiSnapshot) {
          return Card(
            color: cardColor,
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: _buildPoiImage(poiSnapshot),
              title: Text(
                poiSnapshot.hasData
                    ? (poiSnapshot.data!['name'] ?? 'Loading...')
                    : 'Loading...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
                  if (journalWidget != null) journalWidget, // ⭐️ ADDED THIS
                ],
              ),
              trailing: highlightIcon,
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

  // ... (Your _buildPoiImage, _navigateToEditor, and _buildDeleteBackground
  // ... functions are all perfect. No changes needed.) ...

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

  Future<void> _navigateToEditor({
    DocumentSnapshot? eventDoc,
    Map<String, dynamic>? poiData,
  }) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventEditorScreen(
          itineraryId: widget.itineraryId,
          itineraryName: widget.itineraryName, // ⭐️ ADD THIS LINE
          eventDoc: eventDoc,
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

  // ⭐️ --- (The MAIN build method is modified) --- ⭐️
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('itineraries')
        .doc(widget.itineraryId)
        .collection('events')
        .orderBy('eventTime')
        .snapshots();

    return Provider<Stream<QuerySnapshot>?>(
      create: (_) => stream,
      child: Scaffold(
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
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasData && _currentEventId == null && !_isToday) {
              _findCurrentEvent();
            }

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

            for (var day in eventsByDate.keys) {
              eventsByDate[day]!.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['eventTime']
                    as Timestamp;
                final bTime = (b.data() as Map<String, dynamic>)['eventTime']
                    as Timestamp;
                return aTime.compareTo(bTime);
              });
            }

            final sortedDates = eventsByDate.keys.toList()..sort();

            final now = DateTime.now();

            return ListView.builder(
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final events = eventsByDate[date]!;
                final dayNumber = index + 1;

                final bool isForToday = _isSameDay(date, now);

                final List<Widget> dayWidgets = [];
                for (int i = 0; i < events.length; i++) {
                  final eventDoc = events[i];
                  final bool isCurrent =
                      isForToday && eventDoc.id == _currentEventId;

                  dayWidgets.add(_buildEventItem(
                    eventDoc,
                    isCurrent: isCurrent,
                  ));

                  if (i < events.length - 1) {
                    final nextEventDoc = events[i + 1];
                    dayWidgets.add(
                      _TravelTimeWidget(
                        key: ValueKey("${eventDoc.id}-${nextEventDoc.id}"),
                        eventA: eventDoc,
                        eventB: nextEventDoc,
                      ),
                    );
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Day $dayNumber - ${DateFormat.yMMMEd().format(date)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isForToday)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'TODAY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                ],
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Show on Map'),
                            onPressed: () async {
                              if (events.length < 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You need at least 2 events on this day to show a route.',
                                    ),
                                    backgroundColor: Colors.blueGrey,
                                  ),
                                );
                                return;
                              }
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                              // ⭐️ --- START OF MODIFICATION --- ⭐️
                              final List<Map<String, dynamic>> eventDetails =
                                  [];
                              for (final eventDoc in events) {
                                final event =
                                    eventDoc.data() as Map<String, dynamic>;
                                final poiId =
                                    event['destinationPoiId'] as String?;

                                GeoPoint? coords; // We'll store this here

                                if (poiId != null) {
                                  final poiDoc = await FirebaseFirestore
                                      .instance
                                      .collection('POIs')
                                      .doc(poiId)
                                      .get();
                                  if (poiDoc.exists) {
                                    final poiData = poiDoc.data()!;
                                    final dynamic coordsData =
                                        poiData['coordinates'];

                                    if (coordsData is GeoPoint) {
                                      coords = coordsData;
                                    } else if (coordsData is Map) {
                                      coords = GeoPoint(
                                        coordsData['latitude'] ?? 0.0,
                                        coordsData['longitude'] ?? 0.0,
                                      );
                                    }
                                  }
                                }

                                // Add all event details to our list
                                eventDetails.add({
                                  'name': event['destinationPoiName'] ??
                                      'Custom Event',
                                  'time': event['eventTime'] as Timestamp,
                                  'coordinates':
                                      coords, // Can be null for custom events
                                });
                              }

                              // Create the new data object to send back
                              final Map<String, dynamic> itineraryMap = {
                                'title': widget.itineraryName,
                                'events': eventDetails,
                              };

                              if (context.mounted)
                                Navigator.pop(context); // Pop loading
                              if (context.mounted) {
                                // Pop back with the new map, not the coordinate list
                                Navigator.pop(context, itineraryMap);
                              }
                              // ⭐️ --- END OF MODIFICATION --- ⭐️
                            },
                          ),
                        ],
                      ),
                      Column(
                        children: dayWidgets,
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
            _navigateToEditor();
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ... (Your _TravelTimeWidget is perfectly fine) ...
class _TravelTimeWidget extends StatefulWidget {
  final DocumentSnapshot eventA;
  final DocumentSnapshot eventB;

  const _TravelTimeWidget({
    super.key,
    required this.eventA,
    required this.eventB,
  });

  @override
  State<_TravelTimeWidget> createState() => _TravelTimeWidgetState();
}

class _TravelTimeWidgetState extends State<_TravelTimeWidget> {
  late final Future<String?> _durationFuture;

  @override
  void initState() {
    super.initState();
    _durationFuture = _fetchDuration();
  }

  @override
  void didUpdateWidget(covariant _TravelTimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventA.id != widget.eventA.id ||
        oldWidget.eventB.id != widget.eventB.id) {
      _durationFuture = _fetchDuration();
    }
  }

  Future<String?> _fetchDuration() async {
    final dataA = widget.eventA.data() as Map<String, dynamic>;
    final dataB = widget.eventB.data() as Map<String, dynamic>;
    final poiIdA = dataA['destinationPoiId'] as String?;
    final poiIdB = dataB['destinationPoiId'] as String?;
    if (poiIdA == null || poiIdB == null) {
      return null;
    }
    final poiADoc =
        await FirebaseFirestore.instance.collection('POIs').doc(poiIdA).get();
    final poiBDoc =
        await FirebaseFirestore.instance.collection('POIs').doc(poiIdB).get();
    if (!poiADoc.exists || !poiBDoc.exists) {
      return null;
    }
    GeoPoint? coordsA = _parseCoordinates(poiADoc.data());
    GeoPoint? coordsB = _parseCoordinates(poiBDoc.data());
    if (coordsA == null || coordsB == null) {
      return null;
    }
    final latLngA = LatLng(coordsA.latitude, coordsA.longitude);
    final latLngB = LatLng(coordsB.latitude, coordsB.longitude);

    if (!mounted) return null;
    final duration = await context
        .findAncestorStateOfType<_ItineraryDetailScreenState>()
        ?._getTravelDuration(latLngA, latLngB);

    return duration;
  }

  GeoPoint? _parseCoordinates(Map<String, dynamic>? poiData) {
    if (poiData == null) return null;
    final dynamic coordsData = poiData['coordinates'];
    if (coordsData is GeoPoint) {
      return coordsData;
    } else if (coordsData is Map) {
      return GeoPoint(
        coordsData['latitude'] ?? 0.0,
        coordsData['longitude'] ?? 0.0,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _durationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 24,
            child: Center(
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.drive_eta_rounded,
                  color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                "~ ${snapshot.data} drive",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
