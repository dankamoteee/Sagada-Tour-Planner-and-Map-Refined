// lib/screens/event_journal_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart'; // ⭐️ ADD THIS
import 'package:photo_view/photo_view_gallery.dart'; // ⭐️ ADD THIS

class EventJournalScreen extends StatefulWidget {
  final DocumentSnapshot eventDoc;
  final String itineraryId;

  const EventJournalScreen({
    super.key,
    required this.eventDoc,
    required this.itineraryId,
  });

  @override
  State<EventJournalScreen> createState() => _EventJournalScreenState();
}

class _EventJournalScreenState extends State<EventJournalScreen> {
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  bool _isLoading = false;

  String _eventTitle = 'Event';

  // ⭐️ We now manage two separate lists
  List<String> _existingImageUrls = [];
  final List<XFile> _newImages = [];

  // ⭐️ This list will track URLs to be deleted from Storage
  final List<String> _imagesToDelete = [];

  @override
  void initState() {
    super.initState();
    _loadEventData();
  }

  void _loadEventData() {
    final data = widget.eventDoc.data() as Map<String, dynamic>;
    _eventTitle = data['destinationPoiName'] ?? 'Custom Event';
    _notesController.text = data['journalNotes'] ?? '';
    _existingImageUrls = List<String>.from(data['journalImages'] ?? []);
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70, // Compress images
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImages.addAll(pickedFiles);
      });
    }
  }

  Future<void> _saveJournal() async {
    setState(() => _isLoading = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: You are not logged in.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Delete any photos marked for deletion
      for (final url in _imagesToDelete) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          // Log error but continue
        }
      }

      // 2. Upload any new images
      List<String> newUploadedUrls = [];
      for (final image in _newImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(userId)
            .child('itineraries')
            .child(widget.itineraryId)
            .child(
                '${widget.eventDoc.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        newUploadedUrls.add(url);
      }

      // 3. Combine with *remaining* existing URLs
      final allImageUrls = _existingImageUrls + newUploadedUrls;

      // 4. Update the event document
      await widget.eventDoc.reference.update({
        'journalNotes': _notesController.text,
        'journalImages': allImageUrls,
        'hasJournalEntry':
            allImageUrls.isNotEmpty || _notesController.text.isNotEmpty,
      });

      if (mounted) {
        Navigator.pop(context, 'Journal saved!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save journal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ⭐️ --- START OF NEW HELPER METHODS --- ⭐️

  /// A combined list for building the gallery
  List<dynamic> get _allImages => [..._existingImageUrls, ..._newImages];

  /// Removes an image from the correct list
  void _removeImage(int index) {
    setState(() {
      if (index < _existingImageUrls.length) {
        // This is a network image, add it to the delete queue
        final url = _existingImageUrls.removeAt(index);
        _imagesToDelete.add(url);
      } else {
        // This is a new local image
        _newImages.removeAt(index - _existingImageUrls.length);
      }
    });
  }

  /// Opens the full-screen photo gallery
  void _openPhotoGallery(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: PhotoViewGallery.builder(
            itemCount: _allImages.length,
            pageController: PageController(initialPage: index),
            builder: (context, index) {
              final item = _allImages[index];
              ImageProvider imageProvider;

              if (item is String) {
                // Network image
                imageProvider = CachedNetworkImageProvider(item);
              } else {
                // Local file image
                imageProvider = FileImage(File((item as XFile).path));
              }

              return PhotoViewGalleryPageOptions(
                imageProvider: imageProvider,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
  // ⭐️ --- END OF NEW HELPER METHODS --- ⭐️

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_eventTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: _pickImages,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextButton(
              onPressed: _isLoading ? null : _saveJournal,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- ⭐️ REVAMPED Photo Grid ⭐️ ---
          _buildPhotoGrid(),
          const SizedBox(height: 24),

          const Text(
            'My Journal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Write about your experience...',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ⭐️ --- REVAMPED WIDGET ⭐️ ---
  Widget _buildPhotoGrid() {
    if (_allImages.isEmpty) {
      return InkWell(
        onTap: _pickImages,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 40),
                SizedBox(height: 8),
                Text('Add your photos', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allImages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final item = _allImages[index];
        Widget imageWidget;

        if (item is String) {
          // Display existing network images
          imageWidget = CachedNetworkImage(
            imageUrl: item,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: Colors.grey.shade200),
          );
        } else {
          // Display new local images
          imageWidget = Image.file(
            File((item as XFile).path),
            fit: BoxFit.cover,
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The image
              GestureDetector(
                onTap: () => _openPhotoGallery(index),
                child: imageWidget,
              ),
              // The delete button
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => _removeImage(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4.0),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
