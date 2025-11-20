import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuidelineContent {
  final String type; // 'header' or 'text'
  final String data;

  GuidelineContent({required this.type, required this.data});

  factory GuidelineContent.fromMap(Map<String, dynamic> map) {
    return GuidelineContent(
      type: map['type'] ?? 'text',
      data: map['data'] ?? '',
    );
  }
}

class GuidelineCategory {
  final String id;
  final String title;
  final String subtitle;
  final String iconName;
  final List<GuidelineContent> content;
  final Map<String, String>? keyInfo;
  final int order;

  GuidelineCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.content,
    this.keyInfo,
    required this.order,
  });

  factory GuidelineCategory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    var contentList = (data['content'] as List?)
            ?.map((item) => GuidelineContent.fromMap(item))
            .toList() ??
        [];

    return GuidelineCategory(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      iconName: data['iconName'] ?? 'article_outlined',
      content: contentList,
      keyInfo: data['keyInfo'] != null
          ? Map<String, String>.from(data['keyInfo'])
          : null,
      order: data['order'] ?? 0,
    );
  }

  // Helper to convert string to IconData
  static IconData getIcon(String name) {
    switch (name) {
      case 'shield_outlined':
        return Icons.shield_outlined;
      case 'park_outlined':
        return Icons.park_outlined;
      case 'credit_card_outlined':
        return Icons.credit_card_outlined;
      case 'directions_walk_outlined':
        return Icons.directions_walk_outlined;
      case 'cloud_outlined':
        return Icons.cloud_outlined;
      case 'signal_cellular_alt_outlined':
        return Icons.signal_cellular_alt_outlined;
      case 'local_hospital_outlined':
        return Icons.local_hospital_outlined;
      default:
        return Icons.article_outlined;
    }
  }
}
