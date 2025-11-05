import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PoiCard extends StatelessWidget {
  final Map<String, dynamic> poiData;
  final VoidCallback onTap;

  const PoiCard({super.key, required this.poiData, required this.onTap});

  // In lib/widgets/poi_card.dart

  @override
  Widget build(BuildContext context) {
    // --- START OF FIX ---

    // Safely check the type of 'images'
    final imagesData = poiData['images'];
    List<dynamic>? images;
    if (imagesData is List) {
      images = imagesData;
    }

    // Safely get the imageUrl
    String? imageUrl;
    if (images != null && images.isNotEmpty) {
      imageUrl = images[0] as String?; // Cast here, as it's safer
    } else {
      // Fallback to 'imageUrl' if 'images' is not a list or is empty
      imageUrl = poiData['imageUrl'] as String?;
    }

    // --- END OF FIX ---

    // Get the distance text, same as before.
    final distance = poiData['distance'] as double?;
    String distanceText = '';
    if (distance != null) {
      if (distance < 1000) {
        distanceText = '${distance.toStringAsFixed(0)} m away';
      } else {
        distanceText = '${(distance / 1000).toStringAsFixed(1)} km away';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        // ... (rest of the widget is unchanged)
        height: 140,
        clipBehavior: Clip
            .antiAlias, // This ensures the borderRadius is respected by children.
        decoration: BoxDecoration(
          color: Colors.grey[300], // A fallback color
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // Use a Stack to layer the text on top of the image.
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- REPLACE THE IMAGE WIDGET ---
            if (imageUrl != null && imageUrl.isNotEmpty) // Added empty check
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                // Show a loading spinner while the image downloads
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
                // Show an error icon if the download fails
                errorWidget: (context, url, error) => const Icon(
                  Icons.image_not_supported,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.image_not_supported, color: Colors.white),

            // ... (rest of the Stack is unchanged)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 0.7, 1.0], // Control where the gradient starts
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poiData['name'] ?? 'Unnamed',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white, // White text for readability
                        shadows: [Shadow(blurRadius: 2.0)], // A subtle shadow
                      ),
                      maxLines: 2, // Allow for two lines for longer names
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (distanceText.isNotEmpty)
                      Text(
                        distanceText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70, // Slightly dimmer color
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
