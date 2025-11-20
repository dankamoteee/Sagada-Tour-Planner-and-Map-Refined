import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String? imageUrl;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    this.imageUrl,
  });

  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CalendarEvent(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'],
    );
  }
}
