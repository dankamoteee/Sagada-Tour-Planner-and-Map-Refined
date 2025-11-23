import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PoiCard extends StatelessWidget {
  final Map<String, dynamic> poiData;
  final VoidCallback onTap;

  const PoiCard({super.key, required this.poiData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // --- START OF NEW, ROBUST IMAGE LOGIC ---

    // 1. Try to get the new 'primaryImage'
    final String? primaryImage = poiData['primaryImage'] as String?;

    // 2. Try to get the 'images' list
    final List<dynamic>? imagesList = poiData['images'] as List<dynamic>?;

    // 3. Try to get the old 'imageUrl' (for backward compatibility)
    final String? legacyImageUrl = poiData['imageUrl'] as String?;

    // Find the best available image URL
    String? displayImageUrl;
    if (primaryImage != null && primaryImage.isNotEmpty) {
      displayImageUrl = primaryImage;
    } else if (imagesList != null && imagesList.isNotEmpty) {
      displayImageUrl = imagesList[0] as String?;
    } else if (legacyImageUrl != null && legacyImageUrl.isNotEmpty) {
      displayImageUrl = legacyImageUrl;
    }
    // --- END OF NEW, ROBUST IMAGE LOGIC ---

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
            // --- UPDATED IMAGE WIDGET ---
            if (displayImageUrl != null && displayImageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: displayImageUrl,
                // 🚀 PERFORMANCE UPGRADE:
                // This tells Flutter to decode the image at a smaller size, saving RAM.
                memCacheHeight: 400,
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
