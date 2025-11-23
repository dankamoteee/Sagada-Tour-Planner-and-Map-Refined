import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerService {
  final Map<String, BitmapDescriptor> _iconCache = {};

  /// ⭐️ REFINED ZOOM LOGIC ⭐️
  List<Map<String, dynamic>> filterPoisByZoom({
    required List<Map<String, dynamic>> allPois,
    required double zoomLevel,
  }) {
    if (zoomLevel < 13) {
      return allPois.where((p) => p['type'] == 'Tourist Spots').toList();
    } else if (zoomLevel < 15.0) {
      return allPois.where((p) {
        final t = p['type'];
        return t == 'Tourist Spots' ||
            t == 'Accommodations' ||
            t == 'Transport Terminals' ||
            t == 'Transport Routes and Terminals';
      }).toList();
    } else if (zoomLevel < 17.0) {
      return allPois.where((p) {
        final t = p['type'];
        return t == 'Tourist Spots' ||
            t == 'Accommodations' ||
            t == 'Transport Terminals' ||
            t == 'Transport Routes and Terminals' ||
            t == 'Food & Dining' ||
            t == 'Business Establishments';
      }).toList();
    } else {
      return allPois;
    }
  }

  /// Creates markers with Dynamic "Dot" Logic & Scaled Tourist Spots
  Future<Set<Marker>> createMarkers({
    required List<Map<String, dynamic>> poiList,
    required double zoomLevel,
    required Function(Map<String, dynamic>) onTap,
    String? highlightedId,
  }) async {
    final Set<Marker> markers = {};

    // Default label rule: Only show when zoomed in close
    final bool defaultShowLabels = zoomLevel >= 17.5;

    for (final data in poiList) {
      // ⭐️ 1. DETERMINE HIGHLIGHT STATUS FIRST ⭐️
      final bool isHighlighted = highlightedId == data['id'];

      bool useDot = false;
      bool showLabel = defaultShowLabels;
      double scale = 1.0;

      final String type = data['type'] ?? '';

      // 2. STANDARD LOGIC (Your existing rules)
      if (type == 'Tourist Spots') {
        useDot = false;
        showLabel = true;
        scale = 1.3;
      } else if (type == 'Accommodations' || type.contains('Transport')) {
        useDot = zoomLevel < 15.0;
      } else {
        useDot = zoomLevel < 17.0;
      }

      // ⭐️ 3. HIGHLIGHT OVERRIDE (The Fix) ⭐️
      // If this marker is clicked, we FORCE it to be fully visible and large.
      if (isHighlighted) {
        useDot = false; // Never show a dot if selected
        showLabel = true; // Always show the name
        scale = 1.3; // Boost base scale to match Tourist Spots
      }

      final marker = await _createSingleMarker(
        data: data,
        showLabel: showLabel,
        useDot: useDot,
        scale: scale,
        onTap: onTap,
        isHighlighted: isHighlighted,
      );
      if (marker != null) {
        markers.add(marker);
      }
    }
    return markers;
  }

  Future<Marker?> _createSingleMarker({
    required Map<String, dynamic> data,
    required bool showLabel,
    required bool useDot,
    required double scale,
    required Function(Map<String, dynamic>) onTap,
    required bool isHighlighted,
  }) async {
    final String category = data['type'] ?? '';
    String label = data['name'] ?? 'POI';
    if (label.length > 25) {
      label = "${label.substring(0, 25)}...";
    }

    // 1. DECLARE BASE VARIABLES
    IconData iconData;
    Color baseColor; // Use 'baseColor' to prevent conflict

    // 2. ASSIGN BASE VALUES (Inside the switch)
    switch (category) {
      case 'Tourist Spots':
        iconData = Icons.landscape;
        baseColor = Colors.green.shade700;
        break;
      case 'Food & Dining':
        iconData = Icons.restaurant;
        baseColor = Colors.orange.shade700;
        break;
      case 'Business Establishments':
        final String name = label.toLowerCase();
        if (name.contains('souvenir') || name.contains('weaving')) {
          iconData = Icons.local_mall;
          baseColor = Colors.purpleAccent.shade700;
        } else if (name.contains('market') || name.contains('grocery')) {
          iconData = Icons.shopping_cart;
          baseColor = Colors.teal.shade700;
        } else if (name.contains('bank') || name.contains('atm')) {
          iconData = Icons.attach_money;
          baseColor = Colors.green.shade800;
        } else {
          iconData = Icons.store;
          baseColor = Colors.blue.shade700;
        }
        break;
      case 'Accommodations':
        iconData = Icons.hotel;
        baseColor = Colors.purple.shade700;
        break;
      case 'Transport Routes and Terminals':
      case 'Transport Terminals':
        iconData = Icons.directions_bus;
        baseColor = Colors.indigo.shade700;
        break;
      case 'Agencies and Offices':
        iconData = Icons.business;
        baseColor = Colors.blueGrey.shade600;
        break;
      case 'Services':
        iconData = Icons.local_atm;
        baseColor = Colors.blueGrey.shade600;
        break;
      case 'Parking':
        iconData = Icons.local_parking;
        baseColor = Colors.red.shade700;
        break;
      default:
        iconData = Icons.location_pin;
        baseColor = Colors.grey.shade700;
    }

    // 3. APPLY HIGHLIGHT OVERRIDES (After base color is determined)
    double finalScale = scale;
    Color finalColor = baseColor;
    bool finalUseDot = useDot;
    int finalZIndex;

    if (isHighlighted) {
      finalScale = scale * 1.5;
      finalColor = Colors.red.shade700; // ⭐️ This override now works!
      finalUseDot = false; // Never a dot when highlighted
      finalZIndex = 10; // Highest Z-Index
    } else {
      finalZIndex =
          category == 'Tourist Spots' ? 5 : (showLabel ? 4 : (useDot ? 2 : 3));
    }

    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    if (lat == null || lng == null) return null;

    final String styleKey = finalUseDot ? "dot" : "pin";
    final String labelKey = showLabel ? label : "nolabel";
    // Use finalColor/finalScale for cache key
    final String cacheKey =
        '${finalColor.value}-$styleKey-$labelKey-$iconData-$finalScale';

    BitmapDescriptor icon;
    if (_iconCache.containsKey(cacheKey)) {
      icon = _iconCache[cacheKey]!;
    } else {
      if (finalUseDot) {
        icon = await _createDotMarkerBitmap(finalColor); // Use finalColor
      } else {
        icon = await _createPinMarkerBitmap(
          iconData,
          finalColor, // Use finalColor
          label: showLabel ? label : null,
          scale: finalScale, // Use finalScale
        );
      }
      _iconCache[cacheKey] = icon;
    }

    return Marker(
      markerId: MarkerId(data['id'] ?? 'unknown'),
      position: LatLng(lat, lng),
      icon: icon,
      // Use finalUseDot for anchor calculation
      anchor: finalUseDot ? const Offset(0.5, 0.5) : const Offset(0.5, 0.85),
      zIndex: finalZIndex.toDouble(),
      onTap: () => onTap(data),
    );
  }

  Future<BitmapDescriptor> _createDotMarkerBitmap(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(40, 40);
    final center = Offset(size.width / 2, size.height / 2);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, 10, shadowPaint);

    final borderPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 9, borderPaint);

    final fillPaint = Paint()..color = color;
    canvas.drawCircle(center, 7, fillPaint);

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createPinMarkerBitmap(
    IconData iconData,
    Color backgroundColor, {
    String? label,
    double scale = 1.0, // ⭐️ NEW: Scale Factor
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Apply Scale to Base Sizes
    final double fixedPinWidth = 50.0 * scale;
    final double pinHeight = 60.0 * scale;
    final double fontSize = 20.0 * scale; // Scale text too
    final double circleRadius = fixedPinWidth / 2;

    // 2. Setup Text Painters
    TextPainter? strokePainter;
    TextPainter? fillPainter;
    double textWidth = 0;
    double textHeight = 0;

    if (label != null) {
      // Stroke (Outline)
      strokePainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.0 * scale // Scale stroke thickness
              ..color = Colors.white,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      strokePainter.layout(maxWidth: 400 * scale);

      // Fill (Color)
      fillPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: backgroundColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      fillPainter.layout(maxWidth: 400 * scale);

      textWidth = fillPainter.width;
      textHeight = fillPainter.height;
    }

    // 3. Dynamic Canvas Size (Scaled)
    final double canvasWidth =
        math.max(120.0 * scale, textWidth + (20.0 * scale));
    final double canvasHeight = pinHeight + textHeight + (15.0 * scale);
    final double centerX = canvasWidth / 2;

    // 4. Draw Pin
    final circleCenter = Offset(centerX, circleRadius);

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 2 * scale);

    final pointerPath = Path();
    pointerPath.moveTo(centerX, pinHeight);
    pointerPath.lineTo(circleCenter.dx - (circleRadius * 0.5), circleCenter.dy);
    pointerPath.lineTo(circleCenter.dx + (circleRadius * 0.5), circleCenter.dy);
    pointerPath.close();

    // Draw Shadow
    canvas.drawPath(
        pointerPath.shift(Offset(1 * scale, 1 * scale)), shadowPaint);
    canvas.drawCircle(circleCenter.translate(1 * scale, 1 * scale),
        circleRadius, shadowPaint);

    // Draw Body
    canvas.drawPath(pointerPath, fillPaint);
    canvas.drawCircle(circleCenter, circleRadius, fillPaint);

    // 5. Draw Icon (Scaled)
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 28 * scale, // Scale Icon
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        centerX - (iconPainter.width / 2),
        (circleRadius * 2 - iconPainter.height) / 2,
      ),
    );

    // 6. Draw Label
    if (label != null && strokePainter != null && fillPainter != null) {
      final textOffset = Offset(
        centerX - (textWidth / 2),
        pinHeight + (5 * scale),
      );
      strokePainter.paint(canvas, textOffset);
      fillPainter.paint(canvas, textOffset);
    }

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}
