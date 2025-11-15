// In lib/screens/itinerary_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // ⭐️ ADD THIS
import 'package:shared_preferences/shared_preferences.dart'; // ⭐️ ADD THIS
import 'itineraries_list_screen.dart';
import 'itinerary_detail_screen.dart'; // ⭐️ ADD THIS

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  // ⭐️ USE A STREAM FOR LIVE UPDATES
  Stream<QuerySnapshot>? _eventsStream;
  String _activeItineraryId = '';
  String _activeItineraryName = 'My Itinerary';

  @override
  void initState() {
    super.initState();
    _loadActiveItineraryStream();
  }

  // ⭐️ This screen needs to update if the user changes the active trip
  // We can use a simple trick by reloading when the user logs in/out
  // or by just re-initializing the state.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadActiveItineraryStream();
  }

  // ⭐️ REPLACED _fetchItinerary with this
  Future<void> _loadActiveItineraryStream() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _eventsStream = null);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final itineraryId = prefs.getString('activeItineraryId');

    if (itineraryId == null || itineraryId.isEmpty) {
      if (mounted) setState(() => _eventsStream = null);
      return;
    }

    // ⭐️ If the ID is the same, don't rebuild the stream
    if (itineraryId == _activeItineraryId && _eventsStream != null) {
      return;
    }

    if (mounted) {
      setState(() {
        _activeItineraryId = itineraryId;
        _activeItineraryName =
            prefs.getString('activeItineraryName') ?? 'My Itinerary';
        _eventsStream = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('itineraries')
            .doc(_activeItineraryId)
            .collection('events')
            .orderBy('eventTime')
            .snapshots();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _eventsStream,
        builder: (context, snapshot) {
          // ⭐️ Handle loading and empty states
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: themeColor));
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty ||
              _eventsStream == null) {
            return _EmptyState(
              onGoToPlans: () {
                // ⭐️ Helper to navigate user to the list screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ItinerariesListScreen(),
                  ),
                );
              },
            );
          }

          // --- ⭐️ THIS IS THE LOGIC FROM ItineraryDetailScreen ⭐️ ---
          // It groups events by day
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
          // --- ⭐️ END OF COPIED LOGIC ⭐️ ---

          return DefaultTabController(
            length: sortedDates.length,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 220.0,
                    pinned: true,
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    actions: [
                      // ⭐️ ADD A BUTTON TO EDIT THE ACTIVE TRIP
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        tooltip: 'Edit Active Trip',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ItineraryDetailScreen(
                                itineraryId: _activeItineraryId,
                                itineraryName: _activeItineraryName,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        _activeItineraryName, // ⭐️ USE ACTIVE NAME
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/itinerary_background.jpg',
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    bottom: TabBar(
                      isScrollable: true,
                      tabs: sortedDates.map((date) {
                        final dayNumber = sortedDates.indexOf(date) + 1;
                        return Tab(text: 'Day $dayNumber');
                      }).toList(),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: sortedDates.map((date) {
                  final events = eventsByDate[date]!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final eventDoc = events[index];
                      final event = eventDoc.data() as Map<String, dynamic>;
                      // ⭐️ We'll use a new card widget for this
                      return _ItineraryEventCard(
                        event: event,
                        index: index,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------
// --- NEW WIDGETS FOR THIS SCREEN ---
// ------------------------------------------

// ⭐️ This is a *simplified* card. It doesn't fetch POI data
// to keep this screen fast. It just shows what's in the 'event' doc.
class _ItineraryEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final int index;

  const _ItineraryEventCard({required this.event, required this.index});

  @override
  Widget build(BuildContext context) {
    final eventTime = (event['eventTime'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          child: Text(
            '${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          event['destinationPoiName'] ?? 'Event',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(DateFormat.jm().format(eventTime)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}

// ⭐️ This is the NEW empty state
class _EmptyState extends StatelessWidget {
  final VoidCallback onGoToPlans;
  const _EmptyState({required this.onGoToPlans});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.explore_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No Active Trip",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Select an itinerary to see it here.",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text("Choose from My Plans"),
            onPressed: onGoToPlans,
          )
        ],
      ),
    );
  }
}
