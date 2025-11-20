import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerService {
  // Cache to prevent re-drawing the same icon 100 times
  final Map<String, BitmapDescriptor> _iconCache = {};

  /// ⭐️ NEW: Decides which POIs to show based on Zoom level
  List<Map<String, dynamic>> filterPoisByZoom({
    required List<Map<String, dynamic>> allPois,
    required double zoomLevel,
  }) {
    if (zoomLevel < 13) {
      // Zoom 0-12 (Far): Show ONLY major Tourist Spots
      return allPois.where((p) => p['type'] == 'Tourist Spots').toList();
    } else if (zoomLevel < 15.5) {
      // Zoom 13-15 (Town View): Add Hotels & Food
      return allPois.where((p) {
        final t = p['type'];
        return t == 'Tourist Spots' ||
            t == 'Accommodations' ||
            t == 'Food & Dining' ||
            t == 'Transport Terminals';
      }).toList();
    } else {
      // Zoom 16+ (Street View): Show EVERYTHING
      return allPois;
    }
  }

  /// ⭐️ NEW: Creates a Set of Markers from a list
  Future<Set<Marker>> createMarkers({
    required List<Map<String, dynamic>> poiList,
    required double zoomLevel,
    required Function(Map<String, dynamic>) onTap,
  }) async {
    final Set<Marker> markers = {};
    // Only show text labels when zoomed in close
    final bool showLabels = zoomLevel >= 16.0;

    for (final data in poiList) {
      final marker = await _createSingleMarker(
        data: data,
        showLabel: showLabels,
        onTap: onTap,
      );
      if (marker != null) {
        markers.add(marker);
      }
    }
    return markers;
  }

  // ⭐️ RESTORED: Your original logic to choose icons and colors
  Future<Marker?> _createSingleMarker({
    required Map<String, dynamic> data,
    required bool showLabel,
    required Function(Map<String, dynamic>) onTap,
  }) async {
    final String category = data['type'] ?? '';

    // Limit label length
    String label = data['name'] ?? 'POI';
    if (label.length > 15) {
      label = "${label.substring(0, 15)}...";
    }

    IconData iconData;
    Color color;

    // Assign colors based on category
    switch (category) {
      case 'Tourist Spots':
        iconData = Icons.landscape;
        color = Colors.green.shade700;
        break;
      case 'Business Establishments':
      case 'Food & Dining': // 👈 Separate this!
        iconData = Icons.restaurant;
        color = Colors.orange.shade700; // Distinct Orange color
        break;
      case 'Accommodations':
        iconData = Icons.hotel;
        color = Colors.purple.shade700;
        break;
      case 'Transport Routes and Terminals':
      case 'Transport Terminals':
        iconData = Icons.directions_bus;
        color = Colors.orange.shade800;
        break;
      case 'Agencies and Offices':
        iconData = Icons.business;
        color = Colors.red.shade700;
        break;
      case 'Services':
        iconData = Icons.local_atm;
        color = Colors.red.shade700;
        break;
      case 'Parking':
        iconData = Icons.local_parking;
        color = Colors.red.shade700;
        break;
      default:
        iconData = Icons.location_pin;
        color = Colors.grey.shade700;
    }

    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;

    if (lat == null || lng == null) return null;

    // Check Cache first
    final String cacheKey = '${color.value}-${showLabel ? label : "no_label"}';
    BitmapDescriptor icon;

    if (_iconCache.containsKey(cacheKey)) {
      icon = _iconCache[cacheKey]!;
    } else {
      // Create the custom bitmap if not cached
      icon = await _createPinMarkerBitmap(
        iconData,
        color,
        label: showLabel ? label : null,
      );
      _iconCache[cacheKey] = icon;
    }

    return Marker(
      markerId: MarkerId(data['id'] ?? 'unknown'),
      position: LatLng(lat, lng),
      icon: icon,
      anchor: const Offset(0.5, 0.8), // Anchor at the bottom tip of the pin
      zIndex: category == 'Tourist Spots' ? 2 : 1, // Draw spots on top
      onTap: () => onTap(data),
    );
  }

  // ⭐️ RESTORED: Your original Canvas Drawing Logic
  Future<BitmapDescriptor> _createPinMarkerBitmap(
    IconData iconData,
    Color backgroundColor, {
    String? label,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final size = const Size(120, 90);
    final pinSize = const Size(50, 60);

    final circleRadius = pinSize.width / 2;
    final circleCenter = Offset(size.width / 2, circleRadius);

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    // Draw Pin Shape
    final pointerPath = Path();
    pointerPath.moveTo(size.width / 2, pinSize.height);
    pointerPath.lineTo(circleCenter.dx - (circleRadius * 0.5), circleCenter.dy);
    pointerPath.lineTo(circleCenter.dx + (circleRadius * 0.5), circleCenter.dy);
    pointerPath.close();

    canvas.drawPath(pointerPath.shift(const Offset(1, 1)), shadowPaint);
    canvas.drawCircle(circleCenter.translate(1, 1), circleRadius, shadowPaint);
    canvas.drawPath(pointerPath, fillPaint);
    canvas.drawCircle(circleCenter, circleRadius, fillPaint);

    // Draw Icon
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 28,
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        (size.width - iconPainter.width) / 2,
        (circleRadius * 2 - iconPainter.height) / 2,
      ),
    );

    // Draw Label
    if (label != null) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            backgroundColor:
                Colors.white, // Optional: Background for readability
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout(maxWidth: 300);

      labelPainter.paint(
        canvas,
        Offset(
          (size.width - labelPainter.width) / 2,
          pinSize.height + 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      (pinSize.height + 25).toInt(), // Increased slightly to fit label
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}
