// lib/screens/itineraries_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// Note: shared_preferences import removed as Provider handles storage now
import 'package:timeago/timeago.dart' as timeago;
import '../services/tutorial_service.dart';
import 'itinerary_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/itinerary_provider.dart';

class ItinerariesListScreen extends StatefulWidget {
  const ItinerariesListScreen({super.key});

  @override
  State<ItinerariesListScreen> createState() => _ItinerariesListScreenState();
}

class _ItinerariesListScreenState extends State<ItinerariesListScreen> {
  final GlobalKey _fabKey = GlobalKey();
  // 🗑️ REMOVED: String? _activeItineraryId; (Provider holds this now)

  @override
  void initState() {
    super.initState();
    // 🗑️ REMOVED: _loadActiveItinerary(); (Provider loads it in main.dart)

    // Tutorial Logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          TutorialService.showListTutorial(
            context: context,
            createKey: _fabKey,
          );
        }
      });
    });
  }

  // ⭐️ UPDATED: Uses Provider instead of SharedPreferences/setState
  void _setActiveItinerary(String itineraryId, String itineraryName) {
    context
        .read<ItineraryProvider>()
        .setActiveItinerary(itineraryId, itineraryName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("'$itineraryName' set as your active trip!"),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  Future<void> _createNewItinerary(BuildContext context, String userId) async {
    final TextEditingController nameController = TextEditingController();
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Itinerary'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: "e.g., 'Family Vacation'",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Create'),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(context).pop(nameController.text);
              }
            },
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final newItineraryRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('itineraries')
          .add({
        'name': newName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastModified': FieldValue.serverTimestamp(),
        'lastEventDate': null,
        'totalEvents': 0,
      });

      if (context.mounted) {
        // ⭐️ Uses the updated method that calls Provider
        _setActiveItinerary(newItineraryRef.id, newName);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ItineraryDetailScreen(
              itineraryId: newItineraryRef.id,
              itineraryName: newName,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color themeColor = Theme.of(context).primaryColor;

    // ⭐️ READ FROM PROVIDER (Listens for changes automatically)
    final activeItineraryId =
        context.watch<ItineraryProvider>().activeItineraryId;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Itineraries')),
        body: const Center(
          child: Text("Please log in to view your itineraries."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "My Itineraries",
                style: TextStyle(
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
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
              child: _UpcomingEventCard(userId: user.uid),
            ),
          ),

          // --- 1. Upcoming Plans ---
          _ItineraryListSection(
            title: 'Upcoming Plans',
            icon: Icons.explore_outlined,
            query: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('itineraries')
                .where('lastEventDate', isGreaterThanOrEqualTo: Timestamp.now())
                .orderBy('lastEventDate', descending: false),
            activeItineraryId: activeItineraryId, // ⭐️ Uses provider value
            onSetActive: _setActiveItinerary, // ⭐️ Uses helper method
            emptyMessage: "No upcoming trips. Plan one!",
          ),

          // --- 2. Past Journals ---
          _ItineraryListSection(
            title: 'Past Journals',
            icon: Icons.history_edu_outlined,
            query: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('itineraries')
                .where('lastEventDate', isLessThan: Timestamp.now())
                .orderBy('lastEventDate', descending: true),
            activeItineraryId: activeItineraryId, // ⭐️ Uses provider value
            onSetActive: _setActiveItinerary,
            emptyMessage: "No past trips found.",
          ),

          // --- 3. Empty/New Plans ---
          _ItineraryListSection(
            title: 'Empty Plans',
            icon: Icons.add_circle_outline_rounded,
            query: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('itineraries')
                .where('totalEvents', isEqualTo: 0)
                .orderBy('lastModified', descending: true),
            activeItineraryId: activeItineraryId, // ⭐️ Uses provider value
            onSetActive: _setActiveItinerary,
            emptyMessage: "Tap '+' to create your first plan.",
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: _fabKey,
        onPressed: () {
          _createNewItinerary(context, user.uid);
        },
        label: const Text('New Itinerary'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// ⭐️ --- REUSABLE WIDGET (Unchanged but verified) --- ⭐️
class _ItineraryListSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Query query;
  final String? activeItineraryId;
  final Function(String, String) onSetActive;
  final String emptyMessage;

  const _ItineraryListSection({
    required this.title,
    required this.icon,
    required this.query,
    required this.activeItineraryId,
    required this.onSetActive,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        emptyMessage,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isActive = doc.id == activeItineraryId;

                    return _ItineraryListCard(
                      itineraryDoc: doc, // ⭐️ Passing Doc for Pending Check
                      itineraryData: data,
                      itineraryId: doc.id,
                      isActive: isActive,
                      onSetActive: () => onSetActive(
                        doc.id,
                        data['name'] ?? 'My Itinerary',
                      ),
                      sectionTitle: title,
                    );
                  },
                  childCount: snapshot.data!.docs.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ... _UpcomingEventCard (Same as before) ...
class _UpcomingEventCard extends StatelessWidget {
  final String userId;
  const _UpcomingEventCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('events')
            .where('userId', isEqualTo: userId)
            .where('eventTime', isGreaterThan: Timestamp.now())
            .orderBy('eventTime')
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return ListTile(
              leading: Icon(
                Icons.wb_sunny_outlined,
                color: Colors.orange.shade700,
              ),
              title: const Text(
                'No upcoming plans!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Your schedule is free.'),
            );
          }

          final event =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final eventTime = (event['eventTime'] as Timestamp).toDate();

          final String? itineraryName = event['itineraryName'] as String?;
          final String eventName = event['destinationPoiName'] ?? 'Event';

          return Container(
            color: Theme.of(context).primaryColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 30,
              ),
              title: Text(
                'Up Next: $eventName',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                (itineraryName != null ? 'From: $itineraryName • ' : '') +
                    'Today at ${DateFormat.jm().format(eventTime)} (${timeago.format(eventTime)})',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ⭐️ --- CORRECTED CARD WIDGET --- ⭐️
class _ItineraryListCard extends StatelessWidget {
  final DocumentSnapshot itineraryDoc;
  final Map<String, dynamic> itineraryData;
  final String itineraryId;
  final bool isActive;
  final VoidCallback onSetActive;
  final String sectionTitle;

  const _ItineraryListCard({
    required this.itineraryDoc,
    required this.itineraryData,
    required this.itineraryId,
    required this.isActive,
    required this.onSetActive,
    required this.sectionTitle,
  });

  @override
  Widget build(BuildContext context) {
    final modified = (itineraryData['lastModified'] as Timestamp?)?.toDate();
    final bool canBeSetConfig = (sectionTitle != 'Past Journals');

    // ⭐️ PENDING SYNC CHECK
    final bool isUnsynced = itineraryDoc.metadata.hasPendingWrites;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isActive ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isActive ? Theme.of(context).primaryColor : Colors.transparent,
          width: 3.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                itineraryData['name'] ?? 'My Itinerary',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // ⭐️ VISUAL INDICATOR
            if (isUnsynced)
              Tooltip(
                message: "Waiting for internet to sync...",
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.cloud_upload_outlined,
                      size: 18, color: Colors.orange.shade700),
                ),
              )
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: ${modified != null ? DateFormat.yMMMd().add_jm().format(modified) : 'N/A'}',
            ),
            // ⭐️ TEXT WARNING
            if (isUnsynced)
              Text(
                "• Saved to device. Syncing...",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800),
              ),
          ],
        ),
        trailing: isActive
            ? Chip(
                label: const Text(
                  "Active",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.8),
                avatar: const Icon(Icons.check_circle,
                    color: Colors.white, size: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              )
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'set_active') {
                    onSetActive();
                  } else if (value == 'view') {
                    _viewItinerary(context);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'view',
                    child: Text('View/Edit'),
                  ),
                  if (canBeSetConfig)
                    const PopupMenuItem<String>(
                      value: 'set_active',
                      child: Text('Set as Active Trip'),
                    ),
                ],
              ),
        onTap: () => _viewItinerary(context),
      ),
    );
  }

  Future<void> _viewItinerary(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ItineraryDetailScreen(
          itineraryId: itineraryId,
          itineraryName: itineraryData['name'] ?? 'My Itinerary',
        ),
      ),
    );

    if (result is Map<String, dynamic>) {
      if (context.mounted) {
        Navigator.pop(context, result);
      }
    } else if (result is List<GeoPoint>) {
      if (context.mounted) {
        Navigator.pop(context, result);
      }
    } else if (result is String && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.red),
      );
    }
  }
}
