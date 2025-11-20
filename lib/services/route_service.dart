import 'dart:convert';
import 'package:flutter/material.dart'; // For Colors (if needed) or debug prints
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as map_tools;
import 'package:html_unescape/html_unescape.dart';

class RouteService {
  // Helper to clean HTML from Google's instructions
  final HtmlUnescape _unescape = HtmlUnescape();

  /// Fetches the raw route data (points and basic stats) from Google API.
  /// Returns null if no route is found or an error occurs.
  Future<Map<String, dynamic>?> getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
    required String mode,
  }) async {
    final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=$mode&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint("❌ API Error: ${response.body}");
        return null;
      }

      final data = json.decode(response.body);
      if (data["routes"].isEmpty) return null;

      // Decode the points
      final String encodedPolyline =
          data["routes"][0]["overview_polyline"]["points"];
      final List<PointLatLng> decodedPoints =
          PolylinePoints.decodePolyline(encodedPolyline);

      final List<LatLng> routePoints =
          decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

      return {
        "points": routePoints,
        "bounds_data": data["routes"][0]["bounds"], // Useful for camera updates
      };
    } catch (e) {
      debugPrint("❌ Error fetching route: $e");
      return null;
    }
  }

  /// Fetches detailed steps, distance, and duration for the Navigation Panel.
  Future<Map<String, dynamic>?> getDirectionsDetails({
    required LatLng origin,
    required LatLng destination,
    required String mode,
  }) async {
    final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=$mode&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data["status"] == "ZERO_RESULTS" || data["routes"].isEmpty) {
          return {
            "distance": "N/A",
            "duration": "N/A",
            "startAddress": "N/A",
            "endAddress": "${destination.latitude}, ${destination.longitude}",
            "steps": [],
          };
        }

        final leg = data["routes"][0]["legs"][0];
        final List<dynamic> stepsData = leg["steps"];

        // Clean the HTML instructions here so the UI doesn't have to
        final List<Map<String, dynamic>> steps = stepsData.map((step) {
          return {
            "instruction": _cleanHtmlString(step["html_instructions"]),
            "distance": step["distance"]["text"],
            "duration": step["duration"]["text"],
            "end_location": LatLng(
              step["end_location"]["lat"],
              step["end_location"]["lng"],
            ),
          };
        }).toList();

        return {
          "distance": leg["distance"]["text"],
          "duration": leg["duration"]["text"],
          "startAddress": leg["start_address"],
          "endAddress": leg["end_address"],
          "steps": steps,
        };
      }
    } catch (e) {
      debugPrint("❌ Error getting details: $e");
    }
    return null;
  }

  /// Calculates if the given [routePoints] intersect with any [closureLines].
  /// Returns true if blocked, false if clear.
  bool isRouteBlocked(List<LatLng> routePoints, Set<Polyline> closureLines) {
    if (closureLines.isEmpty || routePoints.isEmpty) return false;

    for (final point in routePoints) {
      final routePointLatLng =
          map_tools.LatLng(point.latitude, point.longitude);

      for (final line in closureLines) {
        final closureLinePoints = line.points
            .map((p) => map_tools.LatLng(p.latitude, p.longitude))
            .toList();

        // Use the Maps Toolkit logic we extracted
        bool isClose = map_tools.PolygonUtil.isLocationOnPath(
          routePointLatLng,
          closureLinePoints,
          false, // geodesic
          tolerance: 20, // 20-meter buffer
        );

        if (isClose) return true;
      }
    }
    return false;
  }

  String _cleanHtmlString(String htmlString) {
    // This regex removes ALL tags, not just <b>
    final RegExp regExp =
        RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return _unescape.convert(htmlString.replaceAll(regExp, ''));
  }
}
