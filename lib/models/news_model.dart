import 'package:cloud_firestore/cloud_firestore.dart';

class NewsItem {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime postedAt;
  final String author;
  final bool isUrgent;

  NewsItem({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.postedAt,
    required this.author,
    this.isUrgent = false,
  });

  factory NewsItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NewsItem(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'],
      postedAt: (data['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      author: data['author'] ?? 'Admin',
      isUrgent: data['isUrgent'] ?? false,
    );
  }
}
