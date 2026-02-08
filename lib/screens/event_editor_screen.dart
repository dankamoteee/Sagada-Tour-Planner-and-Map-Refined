import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/poi_search_delegate.dart';
import '../services/tutorial_service.dart'; // Ensure this path is correct
import '../services/notification_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class EventEditorScreen extends StatefulWidget {
  final String itineraryId;
  final String itineraryName;
  final DocumentSnapshot? eventDoc; // Pass the event document if editing
  final Map<String, dynamic>? initialPoiData;

  const EventEditorScreen({
    super.key,
    required this.itineraryId,
    required this.itineraryName,
    this.eventDoc,
    this.initialPoiData,
  });

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  // 🆕 ADD THESE 3 KEYS
  final GlobalKey _timeKey = GlobalKey();
  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.eventDoc != null;

  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDateTime;
  Map<String, dynamic>? _selectedDestination;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If we are editing an existing event, pre-fill the form
    if (_isEditing) {
      final data = widget.eventDoc!.data() as Map<String, dynamic>;
      _notesController.text = data['notes'] ?? '';
      _selectedDateTime = (data['eventTime'] as Timestamp?)?.toDate();

      // Store POI data for display
      _selectedDestination = {
        'id': data['destinationPoiId'],
        'name': data['destinationPoiName'],
      };
    } else if (widget.initialPoiData != null) {
      // --- THIS IS THE NEW LOGIC FOR "ADD TO PLAN" ---
      // Pre-fill the destination with the data passed from the POI sheet
      setState(() {
        _selectedDestination = {
          'id': widget.initialPoiData!['id'],
          'name': widget.initialPoiData!['name'],
        };
        // Set a default day and time
        _selectedDateTime = DateTime.now();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Small delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          // Ensure you import '../services/tutorial_service.dart'
          TutorialService.showEventEditorTutorial(
            context: context,
            timeKey: _timeKey,
            locationKey: _locationKey,
            saveKey: _saveKey,
          );
        }
      });
    });
  }

  Future<void> _selectPoi() async {
    final result = await showSearch<Map<String, dynamic>?>(
      context: context,
      delegate: POISearchDelegate(),
    );
    if (result != null) {
      setState(() {
        _selectedDestination = result;
      });
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
    );
    if (time != null) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a destination.')));
      return;
    }
    _selectedDateTime ??= DateTime.now();

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOffline = connectivityResult.contains(ConnectivityResult.none);

    final Map<String, dynamic> eventData = {
      'eventTime': Timestamp.fromDate(_selectedDateTime!),
      'destinationPoiId': _selectedDestination!['id'],
      'destinationPoiName': _selectedDestination!['name'],
      'notes': _notesController.text,
      'userId': user.uid,
      'itineraryId': widget.itineraryId,
      'itineraryName': widget.itineraryName,
    };

    final itineraryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .doc(widget.itineraryId);

    bool saveSuccessful = false; // Track success

    try {
      final batch = FirebaseFirestore.instance.batch();

      final DocumentReference eventRef = _isEditing
          ? itineraryRef.collection('events').doc(widget.eventDoc!.id)
          : itineraryRef.collection('events').doc();

      if (_isEditing) {
        batch.update(eventRef, eventData);
      } else {
        eventData['order'] = DateTime.now().millisecondsSinceEpoch;
        batch.set(eventRef, eventData);
        batch.set(itineraryRef, {'totalEvents': FieldValue.increment(1)},
            SetOptions(merge: true));
      }

      batch.set(itineraryRef, {'lastModified': FieldValue.serverTimestamp()},
          SetOptions(merge: true));

      // 1. Commit (Works offline)
      await batch.commit();
      saveSuccessful = true; // Mark as saved locally

      // 2. Try Online Update (Fail silently if offline)
      if (!isOffline) {
        try {
          final eventTime = eventData['eventTime'] as Timestamp;
          final itineraryDoc = await itineraryRef.get();
          final currentLastEvent =
              itineraryDoc.data()?['lastEventDate'] as Timestamp?;
          if (currentLastEvent == null ||
              eventTime.compareTo(currentLastEvent) > 0) {
            await itineraryRef.update({'lastEventDate': eventTime});
          }
        } catch (e) {
          print("Online metadata update skipped: $e");
        }
      }

      // 3. Try Notifications (Fail silently if error)
      try {
        if (_selectedDateTime != null) {
          NotificationService().scheduleEventNotification(
            id: eventRef.id.hashCode,
            title: _selectedDestination!['name'],
            body:
                "Your trip to ${_selectedDestination!['name']} is starting soon.",
            scheduledTime: _selectedDateTime!,
          );
        }
      } catch (e) {
        print("Notification scheduling failed: $e");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // ⭐️ FORCE CLOSE IF SUCCESSFUL
        if (saveSuccessful) {
          final successMessage = _isEditing
              ? "Updated '${eventData['destinationPoiName']}'"
              : "Added '${eventData['destinationPoiName']}'";
          Navigator.pop(context, successMessage);
        }
      }
    }
  }

  // ... (Your _deleteEvent and build methods are fine here) ...
  Future<void> _deleteEvent() async {
    if (!_isEditing) return;

    // 1. Show a confirmation dialog to the user
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text(
          'Are you sure you want to permanently delete this event from your itinerary?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false), // Return false
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true), // Return true
          ),
        ],
      ),
    );

    // 2. Only proceed if the user confirmed
    if (didConfirm == true) {
      try {
        // Delete the document from Firestore
        await widget.eventDoc!.reference.delete();

        // Pop the screen and send back a success message
        if (mounted) {
          Navigator.pop(context, 'Event deleted successfully!');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'Add New Event'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteEvent),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Day Number
            const SizedBox(height: 16),
            // Date and Time
            ListTile(
              key: _timeKey, // 👈 Assign Key
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date & Time'),
              subtitle: Text(
                _selectedDateTime != null
                    ? DateFormat.yMMMd().add_jm().format(_selectedDateTime!)
                    : 'Tap to select (defaults to now)', // ⭐️ Hint text
              ),
              onTap: _selectDateTime,
            ),
            const SizedBox(height: 16),
            // Destination
            ListTile(
              key: _locationKey, // 👈 Assign Key
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text('Destination'),
              subtitle: Text(
                _selectedDestination?['name'] ?? 'Tap to select a destination',
              ),
              trailing: const Icon(Icons.search),
              onTap: _selectPoi,
            ),
            const SizedBox(height: 16),
            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            // Save Button
            ElevatedButton(
              key: _saveKey, // 👈 Assign Key
              onPressed: _isLoading ? null : _saveEvent,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    )
                  : Text(_isEditing ? 'Update Event' : 'Add Event'),
            ),
          ],
        ),
      ),
    );
  }
}
