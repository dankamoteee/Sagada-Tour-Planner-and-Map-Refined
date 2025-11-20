import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerService {
  final Map<String, BitmapDescriptor> _iconCache = {};

  Future<BitmapDescriptor> _createPinMarkerBitmap(
    IconData iconData,
    Color backgroundColor, {
    String? label,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ⭐️ OPTIMIZATION 2: REDUCED SIZES (50% Smaller) ⭐️
    // Old: 200x160 / 100x120
    // New: 100x80  / 50x60
    final size = const Size(120, 90); // Canvas size
    final pinSize = const Size(50, 60); // Actual colored pin size

    final circleRadius = pinSize.width / 2;
    final circleCenter = Offset(size.width / 2, circleRadius);

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2); // Reduced blur

    // Draw Pin Shape
    final pointerPath = Path();
    pointerPath.moveTo(size.width / 2, pinSize.height);
    pointerPath.lineTo(circleCenter.dx - (circleRadius * 0.5),
        circleCenter.dy); // Sharper point
    pointerPath.lineTo(circleCenter.dx + (circleRadius * 0.5), circleCenter.dy);
    pointerPath.close();

    canvas.drawPath(pointerPath.shift(const Offset(1, 1)), shadowPaint);
    canvas.drawCircle(circleCenter.translate(1, 1), circleRadius, shadowPaint);
    canvas.drawPath(pointerPath, fillPaint);
    canvas.drawCircle(circleCenter, circleRadius, fillPaint);

    // Draw Icon (Scaled down)
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 28, // ⭐️ Reduced from 55
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

    // Draw Label (Scaled down)
    if (label != null) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 14, // ⭐️ Reduced from 28
            fontWeight: FontWeight.w600, // Semi-bold looks better small
            color: Colors.black,
            backgroundColor: Colors.white,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout(
          maxWidth: 300); // Allow text to be wider than the pin if needed

      // Center the text below the pin
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
      size.width
          .toInt(), // Auto-crop width based on text? No, keep fixed for stability
      (pinSize.height + 20).toInt(), // Crop height to fit text
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<Marker> createMarker({
    required Map<String, dynamic> data,
    required void Function(Map<String, dynamic>) onTap,
    required bool showLabel,
  }) async {
    final String category = data['type'] ?? '';
    // Limit label length to avoid massive markers
    String label = data['name'] ?? 'POI';
    if (label.length > 15) {
      label = "${label.substring(0, 15)}...";
    }

    IconData iconData;
    Color color;

    switch (category) {
      case 'Tourist Spots':
        iconData = Icons.landscape;
        color = Colors.green.shade700; // Darker green for better contrast
        break;
      case 'Business Establishments':
      case 'Food & Dining': // Handle your new category
        iconData = Icons.store;
        color = Colors.blue.shade700;
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
      case 'Services': // Handle Services
      case 'Parking': // Handle Parking
        iconData = Icons.local_parking;
        if (category == 'Agencies and Offices') iconData = Icons.business;
        if (category == 'Services') iconData = Icons.local_atm;
        color = Colors.red.shade700;
        break;
      default:
        iconData = Icons.location_pin;
        color = Colors.grey.shade700;
    }

    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    if (lat == null || lng == null) {
      return Marker(markerId: MarkerId(data['id']));
    }

    final String cacheKey = '${color.value}-${showLabel ? label : ""}';

    BitmapDescriptor icon;
    if (_iconCache.containsKey(cacheKey)) {
      icon = _iconCache[cacheKey]!;
    } else {
      icon = await _createPinMarkerBitmap(
        iconData,
        color,
        label: showLabel ? label : null,
      );
      _iconCache[cacheKey] = icon;
    }

    return Marker(
      markerId: MarkerId(data['id']),
      position: LatLng(lat, lng),
      icon: icon,
      anchor: const Offset(0.5, 0.8),
      onTap: () => onTap(data),
      zIndex: category == 'Tourist Spots' ? 2 : 1, // Draw spots on top
    );
  }
}
