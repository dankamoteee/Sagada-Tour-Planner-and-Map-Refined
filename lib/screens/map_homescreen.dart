import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/marker_service.dart';
import '../services/poi_search_delegate.dart';
import '../widgets/profile_menu.dart';
import '../widgets/discovery_panel.dart';
import '../widgets/custom_route_sheet.dart';
import '../widgets/compass_widget.dart';
import '../widgets/transport_browser_sheet.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:app_settings/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'event_editor_screen.dart';
import 'package:flutter_tts/flutter_tts.dart'; // 👈 ADD THIS
import 'package:html_unescape/html_unescape.dart'; // 👈 ADD THIS (for cleaning text)
import 'package:maps_toolkit/maps_toolkit.dart' as map_tools;

// Enum to manage the panel's visibility state
enum NavigationPanelState { hidden, minimized, expanded }

enum LocationButtonState {
  centered,
  offCenter,
  navigating,
  compass,
} // Add compass

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

String _currentTravelMode = "driving"; // driving by default
LatLng? _lastDestination; // remember last POI clicked

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  bool _isFollowingUser = true;
  Map<String, String>? _itinerarySummary; // 👈 ADD THIS
  String? _itineraryTitle;
  List<Map<String, dynamic>> _itineraryEvents = [];
  Map<String, dynamic>? _currentTransportRouteData;
  bool _locationPermissionGranted = false;
  bool _isAnimatingCamera = false;
  bool _tourismReminderShown = false; // 👈 ADD THIS LINE
  bool _isCustomRoutePreview = false;
  bool _isItineraryRouteVisible = false;
  LocationButtonState _locationButtonState = LocationButtonState.offCenter;
  bool _welcomeMessageShown = false;
  bool _isCompassMode = false;
  StreamSubscription<CompassEvent>? _compassSubscription;
  LatLng? _lastKnownPosition;
  double _lastKnownBearing = 0.0;
  String _liveDistance = '';
  String _liveDuration = '';
  String _liveEta = '';
  // Average speed in meters per second
  bool _isNavigating = false; // Tracks live navigation mode
  // New state variables to add to _MapScreenState
  NavigationPanelState _panelState = NavigationPanelState.hidden;
  User? _currentUser;
  Map<String, dynamic>? _userData;
  StreamSubscription? _authSubscription;
  StreamSubscription? _userDataSubscription; // 👈 ADD THIS
  Map<String, dynamic>? _navigationDetails;
  bool _isRouteLoading = false; // To show a loading indicator
  StreamSubscription<Position>? _positionStreamSubscription;
  List<Map<String, dynamic>> _allPoiData = []; // To cache Firestore data
  double _currentZoom = 14.0; // To track the current zoom level
  final double _labelZoomThreshold = 14.0; // The zoom level to show labels
  // --- START: ADD FOR TURN-BY-TURN ---
  late FlutterTts _flutterTts; // The TTS engine
  // ⭐️ --- START OF NEW "HEADS-UP" VARIABLES --- ⭐️
  Stream<QuerySnapshot>? _activeItineraryStream;
  String? _activeItineraryId;
  String? _activeItineraryName; // ⭐️ ADD THIS LINE
  DocumentSnapshot? _activeHeadsUpEvent;
  // ⭐️ --- END OF NEW "HEADS-UP" VARIABLES --- ⭐️
  List<Map<String, dynamic>> _navigationSteps = []; // Holds all steps
  int _currentStepIndex = 0; // Tracks which step we are on
  String _currentInstruction = ""; // The text to display and speak
  bool _isMuted = false; // 👈 ADD THIS
  double _currentSpeed = 0.0; // 👈 ADD THIS
  List<Map<String, dynamic>> _nearbyPois = []; // 👈 ADD THIS LINE
  // --- END: ADD FOR TURN-BY-TURN ---

  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Polyline> _closureLines = {}; // Renamed to store lines
  List<LatLng> _polylineCoordinates = [];

  // Initial location (Sagada center approx)
  static const LatLng _initialPosition = LatLng(17.0885, 120.8996);

  // Map markers
  Set<Marker> _markers = {};

  // Filter options
  final List<String> _filters = [
    'All',
    'Tourist Spots',
    'Business Establishments',
    'Accommodations',
    'Transport Terminals',
    'Agencies and Offices',
  ];
  String _selectedFilter = 'All';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _poiSub;

  late BitmapDescriptor touristIcon;
  late BitmapDescriptor businessIcon;
  late BitmapDescriptor accommodationIcon;
  late BitmapDescriptor transportIcon;
  late BitmapDescriptor agencyIcon;

  Future<BitmapDescriptor> _createDistanceMarkerBitmap(String text) async {
    // 1. Set up the text painter
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 32, // Larger font size
          fontWeight: FontWeight.bold,
          color: Colors.white, // White text for contrast
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // 2. Define the tag's dimensions and style
    final double padding = 16.0;
    final double borderRadius = 16.0;
    final double shadowBlur = 8.0;
    final Size size = Size(
      textPainter.width + padding * 2,
      textPainter.height + padding,
    );
    final Paint backgroundPaint = Paint()
      ..color = Theme.of(context).primaryColor; // Themed background
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);

    // 3. Set up the canvas
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      pictureRecorder,
      Rect.fromLTWH(
        0.0,
        0.0,
        size.width + shadowBlur,
        size.height + shadowBlur,
      ),
    );

    // 4. Draw the shadow
    final RRect shadowRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(shadowBlur / 2, shadowBlur / 2, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(shadowRRect, shadowPaint);

    // 5. Draw the main background shape
    final RRect backgroundRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(backgroundRRect, backgroundPaint);

    // 6. Draw the border
    canvas.drawRRect(backgroundRRect, borderPaint);

    // 7. Draw the text in the center
    textPainter.paint(canvas, Offset(padding, padding / 2));

    // 8. Convert to BitmapDescriptor
    final ui.Image image = await pictureRecorder.endRecording().toImage(
          (size.width + shadowBlur).toInt(),
          (size.height + shadowBlur).toInt(),
        );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createNumberedCircleMarker(int number) async {
    const double size = 70; // The diameter of the circle
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint backgroundPaint = Paint()..color = Colors.orange.shade700;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // Draw the main colored circle
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      backgroundPaint,
    );

    // Draw the white border on top
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 3,
      borderPaint,
    );

    // Prepare and draw the number text
    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.text = TextSpan(
      text: number.toString(),
      style: const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    textPainter.layout();

    // Center the text inside the circle
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  // The main function to draw the itinerary
  Future<void> _drawItineraryRoute(Map<String, dynamic> itineraryData) async {
    // Extract the title and events list
    final String title = itineraryData['title'] ?? 'My Itinerary';
    final List<Map<String, dynamic>> events =
        List<Map<String, dynamic>>.from(itineraryData['events'] ?? []);

    // Filter out events that don't have coordinates
    final List<Map<String, dynamic>> eventsWithCoords =
        events.where((event) => event['coordinates'] != null).toList();

    // Create the coordinates list from the filtered events
    final List<GeoPoint> coordinates = eventsWithCoords
        .map((event) => event['coordinates'] as GeoPoint)
        .toList();

    if (coordinates.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("This day has less than 2 locatable events.")));
      }
      return;
    }

    _endNavigation();

    final String apiKey = "AIzaSyCp73OfWNg7pGMFCe6QVdSCkyPBhwof9dI";

    final LatLng origin = LatLng(
      coordinates.first.latitude,
      coordinates.first.longitude,
    );
    final LatLng destination = LatLng(
      coordinates.last.latitude,
      coordinates.last.longitude,
    );

    String waypoints = "";
    if (coordinates.length > 2) {
      // ⭐️ FIX: Removed "optimize:true|" to force the exact planned order
      waypoints = coordinates
          .sublist(1, coordinates.length - 1)
          .map((geo) => "${geo.latitude},${geo.longitude}")
          .join('|');
    }

    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&waypoints=$waypoints&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["routes"].isNotEmpty) {
        final route = data["routes"][0];
        final legs = route["legs"];

        final Set<Polyline> allPolylines = {};
        int totalDurationSeconds = 0;
        int totalDistanceMeters = 0;

        final String encodedOverviewPolyline =
            route["overview_polyline"]["points"];
        final List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(
          encodedOverviewPolyline,
        );
        final List<LatLng> mainRoutePoints =
            decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

        bool isBlocked = await _checkRouteForClosures(mainRoutePoints);
        if (isBlocked) {
          _endNavigation();
          return;
        }
        allPolylines.add(
          Polyline(
            polylineId: const PolylineId("itinerary_route_main"),
            color: Colors.orange.shade700,
            width: 6,
            points: mainRoutePoints,
          ),
        );

        // Check the Origin Point
        if (legs.isNotEmpty) {
          final firstLeg = legs[0];
          final onRoadStartPoint = LatLng(
            firstLeg["start_location"]["lat"],
            firstLeg["start_location"]["lng"],
          );
          final actualOrigin = LatLng(
            coordinates[0].latitude,
            coordinates[0].longitude,
          );
          if (Geolocator.distanceBetween(
                onRoadStartPoint.latitude,
                onRoadStartPoint.longitude,
                actualOrigin.latitude,
                actualOrigin.longitude,
              ) >
              10) {
            allPolylines.add(
              Polyline(
                polylineId: const PolylineId("itinerary_offroad_origin"),
                color: Colors.orange.shade700,
                width: 5,
                points: [onRoadStartPoint, actualOrigin],
                patterns: [PatternItem.dot, PatternItem.gap(10)],
              ),
            );
          }
        }

        // Loop through legs for end points
        for (int i = 0; i < legs.length; i++) {
          final leg = legs[i];
          totalDurationSeconds += leg["duration"]["value"] as int;
          totalDistanceMeters += leg["distance"]["value"] as int;

          final onRoadEndPoint = LatLng(
            leg["end_location"]["lat"],
            leg["end_location"]["lng"],
          );
          final actualDestination = LatLng(
            coordinates[i + 1].latitude,
            coordinates[i + 1].longitude,
          );

          if (Geolocator.distanceBetween(
                onRoadEndPoint.latitude,
                onRoadEndPoint.longitude,
                actualDestination.latitude,
                actualDestination.longitude,
              ) >
              10) {
            allPolylines.add(
              Polyline(
                polylineId: PolylineId("itinerary_offroad_$i"),
                color: Colors.orange.shade700,
                width: 5,
                points: [onRoadEndPoint, actualDestination],
                patterns: [PatternItem.dot, PatternItem.gap(10)],
              ),
            );
          }
        }

        final String totalDurationText =
            "${(totalDurationSeconds / 60).round()} min"; // New label
        final String totalDistanceText =
            "${(totalDistanceMeters / 1000).toStringAsFixed(1)} km";

        // Prepare numbered markers
        Set<Marker> numberedMarkers = {};
        int markerNum = 1;
        for (int i = 0; i < events.length; i++) {
          if (events[i]['coordinates'] != null) {
            final coords = events[i]['coordinates'] as GeoPoint;
            numberedMarkers.add(
              Marker(
                markerId: MarkerId('itinerary_stop_$i'),
                position: LatLng(
                  coords.latitude,
                  coords.longitude,
                ),
                icon: await _createNumberedCircleMarker(markerNum),
                zIndex: 2,
              ),
            );
            markerNum++;
          }
        }

        // Update the state
        setState(() {
          _polylines = allPolylines;
          _markers.addAll(numberedMarkers);
          _itineraryTitle = title;
          _itineraryEvents = events; // Save the full list
          _itinerarySummary = {
            'duration': totalDurationText,
            'distance': totalDistanceText,
          };
          _isItineraryRouteVisible = true;
        });

        LatLngBounds bounds = _boundsFromLatLngList(mainRoutePoints);
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }
    }
  }

  Future<void> _showWelcomeToast(Map<String, dynamic> userData) async {
    final photoUrl = userData['profilePictureUrl'];
    final fullName = userData['fullName'] ?? 'Explorer';
    final Color themeColor = Theme.of(context).primaryColor;

    // By awaiting showDialog, we can ensure we wait until it's popped.
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        // This internal timer will pop the dialog, which completes the await.
        Future.delayed(const Duration(seconds: 4), () {
          if (context.mounted) {
            Navigator.of(context).pop(true);
          }
        });

        // The rest of the dialog UI remains the same
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: themeColor,
                  // --- REPLACE THIS LINE ---
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(
                          photoUrl,
                        ) // Use the caching provider
                      : null,
                  // --- END OF REPLACEMENT ---
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  'Welcome, $fullName!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: themeColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _rebuildMarkers() async {
    // --- START OF FIX ---
    // If any route (itinerary, regular navigation, or transport) is visible,
    // do not rebuild the base POI markers, as this will wipe out our route pins.
    if (_isItineraryRouteVisible ||
        _navigationDetails != null ||
        _currentTransportRouteData != null) {
      return;
    }
    // --- END OF FIX ---

    final bool showLabels = _currentZoom > _labelZoomThreshold;

    final markers = await Future.wait(
      _allPoiData.map((data) async {
        final markerService = MarkerService();
        return await markerService.createMarker(
          data: data,
          showLabel: showLabels, // Pass the flag here
          onTap: (data) {
            _showPoiSheet(
              name: data['name'] ?? 'Unnamed',
              description: data['description'] ?? 'No description available.',
              data: data,
            );
          },
        );
      }),
    );

    if (mounted) {
      setState(() {
        _markers = Set.from(markers);
      });
    }
  }

  Future<BitmapDescriptor> _createCircleMarkerBitmap(
    Color color, {
    double size = 48,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint borderPaint = Paint()..color = Colors.white;
    final Paint fillPaint = Paint()..color = color;

    final double borderWidth = size * 0.1; // 10% of the size for the border

    // Draw the white border circle
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);
    // Draw the inner colored circle
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - borderWidth,
      fillPaint,
    );

    final img = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  // This is the new, more powerful function
  Future<bool> _drawRoute(
    LatLng origin,
    LatLng destination,
    String mode,
  ) async {
    // Save destination for re-use if needed later
    _lastDestination = destination;

    // 1. GET THE ROUTE DATA USING YOUR EXISTING HTTP METHOD
    final String apiKey = "AIzaSyCp73OfWNg7pGMFCe6QVdSCkyPBhwof9dI"; // Your key
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=$mode&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get directions: ${response.body}")),
      );
      return false; // 👈 2. Add return
    }

    final data = json.decode(response.body);

    if (data["routes"].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No route available for $mode mode here.")),
      );
      return false; // 👈 3. Add return
    }

    // 2. DECODE THE POLYLINE (The new, correct way)
    final String encodedPolyline =
        data["routes"][0]["overview_polyline"]["points"];

    final List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(
      encodedPolyline,
    );

    _polylineCoordinates =
        decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

    if (_polylineCoordinates.isEmpty) return false; // 👈 4. Add return

    // --- ⭐️ ADD THIS CHECK ⭐️ ---
    bool isBlocked = await _checkRouteForClosures(_polylineCoordinates);
    if (isBlocked) {
      _endNavigation(); // Clear the route
      return false; // 👈 5. THIS IS THE KEY FIX
    }
    // --- END OF CHECK ---

    // 3. Create a new Set to hold all our polylines...
    final Set<Polyline> polylines = {};

    // 4. Create the main, solid on-road route polyline
    polylines.add(
      Polyline(
        polylineId: const PolylineId("on_road_route"),
        color: Colors.blue.shade400,
        width: 5,
        points: _polylineCoordinates,
        patterns: mode == 'walking'
            ? [PatternItem.dash(15), PatternItem.gap(10)]
            : [],
      ),
    );

    // 5. Check if the destination is off-road...
    final LatLng lastPointOnRoad = _polylineCoordinates.last;
    final double offRoadDistance = Geolocator.distanceBetween(
      lastPointOnRoad.latitude,
      lastPointOnRoad.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (offRoadDistance > 10) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId("off_road_segment"),
          color: Colors.blue.shade400,
          width: 5,
          points: [lastPointOnRoad, destination],
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ),
      );
    }

    // 6. Create the custom circle icons for start and end
    final BitmapDescriptor startIcon = await _createCircleMarkerBitmap(
      Colors.green.shade600,
    );
    final BitmapDescriptor endIcon = await _createCircleMarkerBitmap(
      Colors.blue.shade600,
    );

    setState(() {
      _polylines = polylines; // Update the state

      _markers.add(
        Marker(
          markerId: const MarkerId('start_pin'),
          position: origin,
          icon: startIcon,
          anchor: const Offset(0.5, 0.5),
          zIndex: 1,
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('end_pin'),
          position: destination,
          icon: endIcon,
          anchor: const Offset(0.5, 0.5),
          zIndex: 1,
        ),
      );
    });

    LatLngBounds bounds = _boundsFromLatLngList([
      origin,
      destination,
      ..._polylineCoordinates,
    ]);
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));

    return true; // 👈 6. Add return (success!)
  }

  // Your old _drawRouteToPoi function now becomes much simpler
  Future<void> _drawRouteToPoi(
    double destLat,
    double destLng,
    String mode,
  ) async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final bool routeDrawn = await _drawRoute(
      LatLng(pos.latitude, pos.longitude),
      LatLng(destLat, destLng),
      mode,
    );

    if (!routeDrawn) return;

    setState(() {
      _isCustomRoutePreview = false;
    });

    final details = await _getDirectionsDetails(
      LatLng(pos.latitude, pos.longitude),
      LatLng(destLat, destLng),
      mode,
    );
    if (details != null && mounted) {
      // --- ⭐️ ADD THIS LINE ⭐️ ---
      // Set a friendly name for the starting point
      details["startAddress"] = "My Location";

      _startNavigation(details);
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double x0 = list.first.latitude, x1 = list.first.latitude;
    double y0 = list.first.longitude, y1 = list.first.longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(southwest: LatLng(x0, y0), northeast: LatLng(x1, y1));
  }

  String _cleanHtmlString(String htmlString) {
    // More specific regex to remove only b tags, but preserve the content
    final RegExp regExp =
        RegExp(r"<\/?b>", multiLine: true, caseSensitive: true);
    // Use html_unescape to handle entities like &amp;
    return HtmlUnescape().convert(htmlString.replaceAll(regExp, ''));
  }

  Future<Map<String, dynamic>?> _getDirectionsDetails(
    LatLng origin,
    LatLng destination,
    String mode,
  ) async {
    final String apiKey =
        "AIzaSyCp73OfWNg7pGMFCe6QVdSCkyPBhwof9dI"; // 👈 use your key
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=$mode&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["status"] == "ZERO_RESULTS") {
        return {
          "distance": "N/A",
          "duration": "N/A",
          // --- ⭐️ ADD THIS LINE ⭐️ ---
          "startAddress": "N/A",
          "endAddress": "${destination.latitude}, ${destination.longitude}",
          "steps": [], // Return empty steps
        };
      }
      if (data["routes"].isNotEmpty) {
        final leg = data["routes"][0]["legs"][0];

        // --- THIS IS THE NEW PART ---
        final List<dynamic> stepsData = leg["steps"];
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
        // --- END OF NEW PART ---

        return {
          "distance": leg["distance"]["text"],
          "duration": leg["duration"]["text"],
          // --- ⭐️ ADD THIS LINE ⭐️ ---
          "startAddress": leg["start_address"],
          "endAddress": leg["end_address"],
          "steps": steps, // Return the parsed steps
        };
      }
    }
    return null;
  }

  Future<void> _loadCustomIcons() async {
    touristIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/tourist.png',
    );
    print("✅ Tourist icon loaded: $touristIcon");
    businessIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/business.png',
    );
    print("✅ Business icon loaded: $businessIcon");
    accommodationIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/accommodation.png',
    );
    print("✅ Accommodation icon loaded: $accommodationIcon");
    transportIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/transport.png',
    );
    print("✅ Transport icon loaded: $transportIcon");
    agencyIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/agency.png',
    );
    print("✅ Agency icon loaded: $agencyIcon");
  }

  // ADD THESE TWO METHODS INSIDE _MapScreenState
  // In _MapScreenState
  Future<bool?> _showResponsibleTourismReminder({
    Map<String, dynamic>? poiData,
  }) async {
    final bool isGuideRequired = poiData?['guideRequired'] as bool? ?? false;
    final guideSubtitle = isGuideRequired
        ? 'This destination requires an accredited guide.'
        : 'For certain sites, a guide may be required. Please verify at the Tourism Office.';

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          contentPadding: EdgeInsets.zero,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),

          title: null,

          // This is the main content of the dialog
          content: SizedBox(
            // Constrain the width of the content. This is the key fix.
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // Make column take up minimum space
                children: [
                  // GIF Animation at the top
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Image.asset(
                      'assets/gifs/tourist_walk.gif', // Your GIF path here
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          'Be a Responsible Tourist!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Information List
                        ListTile(
                          leading: Icon(
                            Icons.app_registration,
                            color: Colors.blue.shade700,
                          ),
                          title: const Text(
                            'Register First',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Always register at the Municipal Tourism Office before proceeding.',
                          ),
                          dense: true,
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.person_search,
                            color: Colors.green.shade700,
                          ),
                          title: const Text(
                            'Secure a Guide',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(guideSubtitle),
                          dense: true,
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.eco,
                            color: Colors.orange.shade700,
                          ),
                          title: const Text(
                            'Leave No Trace',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Respect environment & local culture. Take your trash with you.',
                          ),
                          dense: true,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('I Understand'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        );
      },
    );
  }

// In lib/screens/map_screen.dart

  // In lib/screens/map_homescreen.dart

  void _showCustomRouteSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CustomRouteSheet(),
    );

    if (result != null && result['start'] != null && result['end'] != null) {
      final startPoi = result['start']!;
      final endPoi = result['end']!;

      LatLng? startLatLng;
      LatLng? endLatLng;
      Position? userPos;

      bool needsLocation =
          startPoi['id'] == 'MY_LOCATION' || endPoi['id'] == 'MY_LOCATION';

      if (needsLocation) {
        try {
          // ... (your existing location permission logic is fine) ...
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Location services are disabled.')));
            return;
          }
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location permission denied.')));
            }
            return;
          }
          userPos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to get location: $e')));
          }
          return;
        }
      }

      // --- ⭐️ START OF FIX ⭐️ ---
      // This function will safely parse coordinates
      // whether they are a GeoPoint or a Map
      LatLng _parseCoordinates(dynamic coordsData) {
        if (coordsData is GeoPoint) {
          // It's already a GeoPoint, use it directly
          return LatLng(coordsData.latitude, coordsData.longitude);
        } else if (coordsData is Map) {
          // It's a Map, extract lat/lng
          return LatLng(
            coordsData['latitude'] ?? 0.0,
            coordsData['longitude'] ?? 0.0,
          );
        }
        // Fallback for null or unknown data
        return const LatLng(0, 0);
      }

      // Determine Start LatLng
      if (startPoi['id'] == 'MY_LOCATION' && userPos != null) {
        startLatLng = LatLng(userPos.latitude, userPos.longitude);
      } else {
        // Use the new safe parser
        startLatLng = _parseCoordinates(startPoi['coordinates']);
      }

      // Determine End LatLng
      if (endPoi['id'] == 'MY_LOCATION' && userPos != null) {
        endLatLng = LatLng(userPos.latitude, userPos.longitude);
      } else {
        // Use the new safe parser
        endLatLng = _parseCoordinates(endPoi['coordinates']);
      }
      // --- ⭐️ END OF FIX ⭐️ ---

      _endNavigation();

      final bool routeDrawn = await _drawRoute(
        startLatLng,
        endLatLng,
        _currentTravelMode,
      );

      if (!routeDrawn) return;

      final details = await _getDirectionsDetails(
        startLatLng,
        endLatLng,
        _currentTravelMode,
      );

      if (details != null && mounted) {
        if (startPoi['id'] == 'MY_LOCATION') {
          details["startAddress"] = "My Location";
        }

        setState(() {
          if (startPoi['id'] == 'MY_LOCATION') {
            _isCustomRoutePreview = false;
          } else {
            _isCustomRoutePreview = true;
          }
        });
        _startNavigation(details);
      }
    }
  }

  void _startCompassMode() {
    // We remove the "if (_isCompassMode)" check that caused the timing issue.
    // We also check if a subscription already exists to avoid duplicates.
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((
      CompassEvent event,
    ) async {
      // Make the listener async

      // Set our flag to true so _onCameraMoveStarted ignores this animation.
      _isAnimatingCamera = true;

      // Animate the camera to the new bearing.
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _lastKnownPosition ?? _initialPosition,
            zoom: 17.5,
            tilt: 50.0,
            bearing: event.heading ?? 0,
          ),
        ),
      );

      // After the animation, set the flag back to false.
      // A small delay ensures the 'camera idle' state is reached.
      Future.delayed(const Duration(milliseconds: 200), () {
        _isAnimatingCamera = false;
      });
    });
  }

  void _showTransportRouteDetailsDialog() {
    if (_currentTransportRouteData == null) return;

    final route = _currentTransportRouteData!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(route['routeName'] ?? 'Route Details'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ), // Optional: Nicer corners
        // --- START OF FIX ---
        // Replace ListBody with a Column
        content: Column(
          mainAxisSize:
              MainAxisSize.min, // This is important for Columns in dialogs
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.money),
              title: const Text('Fare'),
              subtitle: Text(route['fareDetails'] ?? 'Not available'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Schedule'),
              subtitle: Text(route['schedule'] ?? 'Not available'),
            ),
          ],
        ),

        // --- END OF FIX ---
        actions: <Widget>[
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _stopCompassMode({bool resetBearing = true}) async {
    _compassSubscription?.cancel();
    _compassSubscription = null; // Clear the subscription
    if (resetBearing) {
      // Set the flag before animating
      _isAnimatingCamera = true;
      // Optionally reset the map to point North
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _lastKnownPosition ?? _initialPosition,
            zoom: 16,
            bearing: 0,
            tilt: 0,
          ),
        ),
      );
      // Unset the flag after animating
      _isAnimatingCamera = false;
    }
  }

  // In map_screen.dart -> inside _MapScreenState

  void _onCameraMoveStarted() {
    // If the user manually moves the map, exit compass or centered mode.
    if (_isAnimatingCamera) return;

    // --- ⭐️ ADD THIS BLOCK ⭐️ ---
    // If we are navigating, a manual move should stop the camera follow
    if (_isNavigating) {
      setState(() {
        _isFollowingUser = false;
      });
    }
    // --- ⭐️ END OF ADDITION ⭐️ ---

    if (_isCompassMode) {
      setState(() {
        _isCompassMode = false;
        _locationButtonState = LocationButtonState.offCenter;
      });
      _stopCompassMode(resetBearing: false);
    } else if (_locationButtonState == LocationButtonState.centered) {
      setState(() {
        _locationButtonState = LocationButtonState.offCenter;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // UPDATED SNACKBAR
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location services are disabled.'),
          action: SnackBarAction(
            label: 'Enable',
            onPressed: () {
              // Opens the device's location settings
              AppSettings.openAppSettings(type: AppSettingsType.location);
            },
          ),
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied.'),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _locationPermissionGranted = true;
      });
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _lastKnownPosition = LatLng(pos.latitude, pos.longitude);

    await _updateNearbyPois(); // 👈 ADD THIS LINE

    if (_locationButtonState == LocationButtonState.centered) {
      // From centered -> enter compass mode
      setState(() {
        _isCompassMode = true;
        _locationButtonState = LocationButtonState.compass;
      });
      _startCompassMode();
    } else {
      // From off-center or compass -> enter centered mode
      setState(() {
        _isCompassMode = false;
        _locationButtonState = LocationButtonState.centered;
      });
      // Await the function so the flag is handled correctly
      await _stopCompassMode();
    }
  }

  // In lib/screens/map_homescreen.dart

  void _showTransportBrowser() async {
    // Now it expects a Map of the full route data
    final Map<String, dynamic>? routeData =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const TransportBrowserSheet(),
    );

    if (routeData != null) {
      // 1. Call the cleanup function FIRST to clear any old route.
      _endNavigation();

      // 2. THEN, set the state with the new route's data.
      // This will make our new _buildTransportRouteDetailsCard() widget appear.
      setState(() {
        _currentTransportRouteData = routeData;
      });

      // --- START OF MODIFICATION ---
      // 3. Check if the route has a polyline to draw.
      final String? encodedPolyline = routeData['polyline'] as String?;

      if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
        // 3a. If we have a route, draw it.
        _drawTransportRoute(routeData);
      } else {
        // 3b. If no route, show the SnackBar.
        // --- START OF FIX ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('This transport type does not have a fixed route.'),
            behavior: SnackBarBehavior.floating, // Make it float
            margin: const EdgeInsets.only(
              bottom: 200.0, // Pushes it up from the bottom (adjust if needed)
              left: 16.0,
              right: 16.0,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        // --- END OF FIX ---
      }
      // --- END OF MODIFICATION ---
    }
  }

  void _drawTransportRoute(Map<String, dynamic> routeData) async {
    final String? encodedPolyline = routeData['polyline'] as String?;
    if (encodedPolyline == null || encodedPolyline.isEmpty) return;

    List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(
      encodedPolyline,
    );

    if (decodedPoints.isNotEmpty) {
      _polylineCoordinates =
          decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

      final LatLng startPoint = _polylineCoordinates.first;
      final LatLng endPoint = _polylineCoordinates.last;

      final BitmapDescriptor startIcon = await _createCircleMarkerBitmap(
        Colors.purple,
        size: 40,
      );
      final BitmapDescriptor endIcon = await _createCircleMarkerBitmap(
        Colors.purple,
        size: 40,
      );

      // --- START OF FIX ---
      // This setState block and the animateCamera call MUST be inside
      // the 'if (decodedPoints.isNotEmpty)' block.
      setState(() {
        _polylines = {
          Polyline(
            polylineId: PolylineId(routeData['routeName'] ?? "transport_route"),
            color: Colors.purple,
            width: 8,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            points: _polylineCoordinates,
            consumeTapEvents: true,
            onTap: () {
              print("Polyline for '${routeData['routeName']}' was tapped!");
              _showTransportRouteDetailsDialog();
            },
          ),
        };

        // Add the markers to the map
        _markers.add(
          Marker(
            markerId: const MarkerId('transport_start'),
            position: startPoint,
            icon: startIcon,
            anchor: const Offset(0.5, 0.5), // Center the icon
          ),
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('transport_end'),
            position: endPoint,
            icon: endIcon,
            anchor: const Offset(0.5, 0.5), // Center the icon
          ),
        );
      });

      LatLngBounds bounds = _boundsFromLatLngList(_polylineCoordinates);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
      // --- END OF FIX ---
    }
  }

  @override
  void initState() {
    super.initState();
    _loadActiveItineraryStream();
    WidgetsBinding.instance.addObserver(this);
    // --- ADD THIS ---
    _flutterTts = FlutterTts();
    // --- END ---

    // Assign to the existing class variable, don't create a new one
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      setState(() {
        _currentUser = user;
      });
      if (user != null) {
        _listenToUserData(user.uid);
      } else {
        _userDataSubscription?.cancel();
        setState(() {
          _userData = null;
        });
      }
    });

    _loadCustomIcons().then((_) {
      _listenToPOIs();
      _listenToClosures();
    });

    /*WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToMyLocation();
    });*/
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadActiveItineraryStream();
  }

  // New function to fetch user data
  // New function to fetch user data
  // In map_screen.dart

  void _listenToUserData(String userId) {
    _userDataSubscription?.cancel();
    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
      // Make the callback async
      (DocumentSnapshot snapshot) async {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _userData = data;
          });

          // --- ADD THIS BLOCK ---
          // Start downloading the image in the background
          final photoUrl = data['profilePictureUrl'] as String?;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            precacheImage(NetworkImage(photoUrl), context);
          }
          // --- END OF BLOCK ---

          if (!_welcomeMessageShown) {
            _welcomeMessageShown = true; // Mark as shown immediately

            // --- REVISED LOGIC ---
            // Step 1: Wait for the welcome toast to show and dismiss.
            await _showWelcomeToast(data);

            // Step 2: Now that the first dialog is gone, show the reminder.
            if (mounted && !_tourismReminderShown) {
              await _showResponsibleTourismReminder();
              setState(() {
                _tourismReminderShown = true;
              });
            }
            if (mounted) {
              await _goToMyLocation();
            }
            // --- END OF REVISED LOGIC ---
          }
        }
      },
      onError: (e) {
        print("Error listening to user data: $e");
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDataSubscription?.cancel();
    _poiSub?.cancel();
    _closureSub?.cancel();
    _mapController?.dispose();

    // --- ADD THIS ---
    _flutterTts.stop();
    // --- END ---

    // --- ADD THESE TWO LINES ---
    _compassSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    // --- END OF FIX ---
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // ⭐️ --- ADD THIS ENTIRE FUNCTION --- ⭐️
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // This checks if the user has returned to the app
    if (state == AppLifecycleState.resumed) {
      print("App resumed: Checking for new active itinerary...");
      // Force a re-check of SharedPreferences
      _loadActiveItineraryStream();
    }
  }
  // ⭐️ --- END OF NEW FUNCTION --- ⭐️

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _setMapStyle('tourism.json');
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter == null) return;
    if (newFilter == _selectedFilter) return;

    setState(() {
      _selectedFilter = newFilter;
    });

    // Re-subscribe with the new query
    _listenToPOIs();
  }

  void _listenToPOIs() {
    _poiSub?.cancel();

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'POIs',
    );
    if (_selectedFilter != 'All') {
      query = query.where('type', isEqualTo: _selectedFilter);
    }

    _poiSub = query.snapshots().listen(
      (snapshot) async {
        // Store the fetched data in our state list
        _allPoiData = snapshot.docs.map((doc) {
          final data = doc.data();
          // Manually add the fields needed by createMarker
          data['id'] = doc.id;
          dynamic coordsData = data['coordinates'];
          if (coordsData is GeoPoint) {
            // Handles data if it's a real GeoPoint
            data['lat'] = coordsData.latitude;
            data['lng'] = coordsData.longitude;
          } else if (coordsData is Map) {
            // Handles data if it's stored as a Map
            data['lat'] = coordsData['latitude'];
            data['lng'] = coordsData['longitude'];
          } else {
            // Fallback in case coordinates are missing
            data['lat'] = null;
            data['lng'] = null;
          }
          return data;
        }).toList();

        // Rebuild the markers with the new data
        await _rebuildMarkers();

        // 👈 ADD THIS LINE
        await _updateNearbyPois();
      },
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to load POIs: $e')));
        }
      },
    );
  }

  void _showPoiSheet({
    required String name,
    required String description,
    required Map<String, dynamic> data,
  }) {
    _saveToRecentlyViewed(data);

    // --- 1. IMAGE CAROUSEL LOGIC (This part is correct) ---
    final List<String> displayImages = [];
    final String? primaryImage = data['primaryImage'] as String?;
    final List<String> otherImages =
        data['images'] != null ? List<String>.from(data['images']) : [];
    final String? legacyImageUrl = data['imageUrl'] as String?;

    if (primaryImage != null && primaryImage.isNotEmpty) {
      displayImages.add(primaryImage);
    }
    for (final imgUrl in otherImages) {
      if (imgUrl != primaryImage) {
        displayImages.add(imgUrl);
      }
    }
    if (displayImages.isEmpty &&
        legacyImageUrl != null &&
        legacyImageUrl.isNotEmpty) {
      displayImages.add(legacyImageUrl);
    }
    // --- END: IMAGE LOGIC ---

    // --- Details (This part is correct) ---
    final poiType = data['type'] as String?;
    final String? openingHours = data['openingHours'] as String?;
    final String? contactNumber = data['contactNumber'] as String?;
    final String? status = data['status'] as String?;
    final bool? guideRequired = data['guideRequired'] as bool?;

    String entranceFeeText = '';
    if (data['entranceFee'] is Map) {
      final feeMap = data['entranceFee'] as Map<String, dynamic>;
      final int? adultFee = (feeMap['adult'] as num?)?.toInt();
      final int? childFee = (feeMap['child'] as num?)?.toInt();

      List<String> feeParts = [];
      if (adultFee != null) {
        feeParts.add('Adult: ₱$adultFee');
      }
      if (childFee != null) {
        feeParts.add('Child: ₱$childFee');
      }
      entranceFeeText = feeParts.join(', ');
      if (entranceFeeText.isEmpty) {
        entranceFeeText = 'Varies';
      }
    } else if (data['entranceFee'] is String) {
      entranceFeeText = data['entranceFee'] as String;
    }
    // --- END: DATA EXTRACTION ---

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        //
        // --- ⭐️ BUG FIX IS HERE ⭐️ ---
        // These variables are now defined OUTSIDE the StatefulBuilder.
        // They will now persist for the life of the bottom sheet.
        final PageController pageController =
            PageController(viewportFraction: 0.88);
        int _currentPage = 0;
        // --- ⭐️ END OF FIX ⭐️ ---

        // --- Use a StatefulBuilder to update the dots ---
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            // We NO LONGER define the controller or page index here.

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Drag handle & POI Name ---
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- STYLISH CAROUSEL UI ---
                        if (displayImages.isNotEmpty)
                          Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: PageView.builder(
                                  // Use the controller defined outside
                                  controller: pageController,
                                  itemCount: displayImages.length,
                                  onPageChanged: (int page) {
                                    // This will now work correctly
                                    setSheetState(() {
                                      _currentPage = page;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    return AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: CachedNetworkImage(
                                          imageUrl: displayImages[index],
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (context, url) =>
                                              const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(Icons.error),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // --- Page Indicator Dots ---
                              if (displayImages.length > 1)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    displayImages.length,
                                    (index) {
                                      return AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        height: 8,
                                        // Reads the _currentPage from outside
                                        width: _currentPage == index ? 24 : 8,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          // Reads the _currentPage from outside
                                          color: _currentPage == index
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey.shade300,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          )
                        else
                          // Placeholder if no images
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey.shade400,
                              size: 50,
                            ),
                          ),
                        // --- END: CAROUSEL UI ---

                        const SizedBox(height: 12),

                        // --- CHIP LAYOUT ---
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            // Fields for Tourist Spots ONLY
                            if (poiType == 'Tourist Spots') ...[
                              if (status != null && status.isNotEmpty)
                                _buildStatusChip(status),
                              if (guideRequired != null)
                                _buildDetailChip(
                                  icon: Icons.person_search_outlined,
                                  label: 'Guide',
                                  value: guideRequired
                                      ? 'Required'
                                      : 'Not Required',
                                ),
                              if (entranceFeeText.isNotEmpty)
                                _buildDetailChip(
                                  icon: Icons.local_activity_outlined,
                                  label: 'Fee',
                                  value: entranceFeeText,
                                ),
                            ],
                            // Fields for NON-Tourist Spots
                            if (poiType != 'Tourist Spots') ...[
                              if (entranceFeeText.isNotEmpty)
                                _buildDetailChip(
                                  icon: Icons.local_activity_outlined,
                                  label: 'Fee',
                                  value: entranceFeeText,
                                ),
                              if (contactNumber != null &&
                                  contactNumber.isNotEmpty)
                                _buildDetailChip(
                                  icon: Icons.phone_outlined,
                                  label: 'Contact',
                                  value: contactNumber,
                                ),
                            ],
                            // Opening Hours (Common to all)
                            if (openingHours != null && openingHours.isNotEmpty)
                              _buildDetailChip(
                                icon: Icons.access_time_outlined,
                                label: 'Hours',
                                value: openingHours,
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- CLEAN DESCRIPTION SECTION ---
                        const Text(
                          "Description",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            description.isEmpty
                                ? "No description available."
                                : description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Action Buttons ---
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                icon: const Icon(Icons.playlist_add),
                                label: const Text("Add to Plan"),
                                onPressed: () async {
                                  // ... (Your existing "Add to Plan" logic)
                                  if (_currentUser == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'You must be logged in to add to a plan.')),
                                    );
                                    return;
                                  }
                                  final Map<String, dynamic>?
                                      selectedItinerary =
                                      await _showItinerarySelectorDialog();
                                  if (selectedItinerary == null) {
                                    return; // User canceled
                                  }
                                  String itineraryId = selectedItinerary['id']!;
                                  if (itineraryId == 'CREATE_NEW') {
                                    final TextEditingController nameController =
                                        TextEditingController();
                                    final String? newName =
                                        await showDialog<String>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('New Itinerary'),
                                        content: TextField(
                                          controller: nameController,
                                          decoration: const InputDecoration(
                                            hintText:
                                                "e.g., 'My Weekend Getaway'",
                                          ),
                                          autofocus: true,
                                        ),
                                        actions: [
                                          TextButton(
                                            child: const Text('Cancel'),
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                          ),
                                          TextButton(
                                            child: const Text('Create'),
                                            onPressed: () {
                                              if (nameController
                                                  .text.isNotEmpty) {
                                                Navigator.of(
                                                  context,
                                                ).pop(nameController.text);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                    if (newName == null || newName.isEmpty)
                                      return;
                                    final newDoc = await FirebaseFirestore
                                        .instance
                                        .collection('users')
                                        .doc(_currentUser!.uid)
                                        .collection('itineraries')
                                        .add({
                                      'name': newName,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'lastModified':
                                          FieldValue.serverTimestamp(),
                                    });
                                    itineraryId = newDoc.id;
                                  }
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  if (mounted) {
                                    final result =
                                        await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => EventEditorScreen(
                                          itineraryId: itineraryId,
                                          initialPoiData: data,
                                          itineraryName: '',
                                        ),
                                      ),
                                    );
                                    if (result is String && mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(result),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Get Directions Button
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                ),
                                icon: const Icon(
                                  Icons.directions,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Get Directions",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context); // Close the POI sheet
                                  final lat = data['lat'] as double?;
                                  final lng = data['lng'] as double?;
                                  if (lat != null && lng != null) {
                                    await _drawRouteToPoi(
                                      lat,
                                      lng,
                                      _currentTravelMode,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

// ... (Your _saveToRecentlyViewed, _buildDetailChip, and _buildStatusChip methods
//     are still needed and are correct as they are) ...

  // Call this when the "Get Directions" button is pressed
  void _startNavigation(Map<String, dynamic> initialDetails) {
    setState(() {
      _navigationDetails = initialDetails;
      _panelState = NavigationPanelState.expanded;

      // 👇 Sync live data with the initial API data
      _liveDistance = initialDetails["distance"] ?? '';
      _liveDuration = initialDetails["duration"] ?? '';
    });

    _updateDistanceMarker(_liveDistance); // Use the live variable
  }

  // Handles changing the travel mode
  Future<void> _updateRoute(String newMode) async {
    if (_lastDestination == null || _currentTravelMode == newMode) return;

    setState(() {
      _isRouteLoading = true;
      _currentTravelMode = newMode;
    });

    final pos = await Geolocator.getCurrentPosition();
    final newDetails = await _getDirectionsDetails(
      LatLng(pos.latitude, pos.longitude),
      _lastDestination!,
      newMode,
    );

    await _drawRouteToPoi(
      _lastDestination!.latitude,
      _lastDestination!.longitude,
      newMode,
    );

    setState(() {
      if (newDetails != null) {
        _navigationDetails = newDetails;
        // 👇 Sync live data when the route is updated
        _liveDistance = newDetails["distance"] ?? '';
        _liveDuration = newDetails["duration"] ?? '';
      }
      _isRouteLoading = false;
    });
  }

  Future<void> _setMapStyle(String fileName) async {
    if (_mapController == null) return;

    // Load the JSON file from assets
    final style = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/map_styles/$fileName');

    // Apply it to the map
    _mapController!.setMapStyle(style);
  }

  // In map_homescreen.dart
  // Replace the whole function with this one.

  // In lib/screens/map_homescreen.dart

  Future<void> _saveToRecentlyViewed(Map<String, dynamic> poiData) async {
    if (_currentUser == null) return; // Only save if a user is logged in

    print("✅ Saving '${poiData['name']}' to recently viewed...");

    final String poiId = poiData['id'];
    final String userId = _currentUser!.uid;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recentlyViewed')
        .doc(poiId);

    // --- START OF NEW, ROBUST IMAGE LOGIC ---
    // 1. Try to get the new 'primaryImage'
    final String? primaryImage = poiData['primaryImage'] as String?;

    // 2. Try to get the 'images' list
    final List<dynamic>? imagesList = poiData['images'] as List<dynamic>?;

    // 3. Try to get the old 'imageUrl' (for backward compatibility)
    final String? legacyImageUrl = poiData['imageUrl'] as String?;

    // Find the best available image URL
    String? recentImageUrl;
    if (primaryImage != null && primaryImage.isNotEmpty) {
      recentImageUrl = primaryImage;
    } else if (imagesList != null && imagesList.isNotEmpty) {
      recentImageUrl = imagesList[0] as String?;
    } else if (legacyImageUrl != null && legacyImageUrl.isNotEmpty) {
      recentImageUrl = legacyImageUrl;
    }
    // --- END OF NEW, ROBUST IMAGE LOGIC ---

    // Use `set` to either create a new record or update the timestamp
    await docRef.set({
      'poiId': poiId,
      'viewedAt': FieldValue.serverTimestamp(),
      'name': poiData['name'],
      'imageUrl': recentImageUrl ?? '', // Use the safely determined URL
    });

    // ... (your existing logic to limit history remains the same)
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recentlyViewed')
        .orderBy('viewedAt', descending: true)
        .limit(20);

    final snapshot = await query.get();
    if (snapshot.docs.length == 20) {
      final lastVisible = snapshot.docs.last;
      final olderItemsQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recentlyViewed')
          .where('viewedAt', isLessThan: lastVisible['viewedAt']);

      final olderItems = await olderItemsQuery.get();
      for (var doc in olderItems.docs) {
        await doc.reference.delete();
      }
    }
  }

  Future<Map<String, dynamic>?> _showItinerarySelectorDialog() async {
    if (_currentUser == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('itineraries')
        .get();

    final itineraries = snapshot.docs;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Itinerary'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 200,
            child: itineraries.isEmpty
                ? const Center(
                    child: Text('No itineraries found. Create one!'),
                  )
                : ListView.builder(
                    itemCount: itineraries.length,
                    itemBuilder: (context, index) {
                      final doc = itineraries[index];
                      final data = doc.data();
                      return ListTile(
                        title: Text(data['name'] ?? 'Untitled Itinerary'),
                        onTap: () {
                          Navigator.pop(context, {
                            'id': doc.id,
                            'name': data['name'],
                          });
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton.icon(
              // A more prominent "Create New" button
              icon: const Icon(Icons.add),
              label: const Text('Create New'),
              onPressed: () {
                Navigator.pop(context, {'id': 'CREATE_NEW', 'name': ''});
              },
            ),
          ],
        );
      },
    );
  }

  /// Checks if a route passes through any known closures.
  /// Returns 'true' if the route is blocked, 'false' if it's clear.
  Future<bool> _checkRouteForClosures(List<LatLng> routePoints) async {
    // Check the new _closureLines set
    if (_closureLines.isEmpty || routePoints.isEmpty) {
      return false; // No closures or route, so it's "clear"
    }

    // Check every point on the user's navigation polyline
    for (final point in routePoints) {
      // Convert the route point to a maps_toolkit LatLng
      final routePointLatLng =
          map_tools.LatLng(point.latitude, point.longitude);

      // Against every closure LINE
      for (final line in _closureLines) {
        // Convert the closure line's points
        final closureLinePoints = line.points
            .map((p) => map_tools.LatLng(p.latitude, p.longitude))
            .toList();

        // ⭐️ --- THE NEW LOGIC --- ⭐️
        // Check if the route point is within 20 meters of the closure line
        bool isClose = map_tools.PolygonUtil.isLocationOnPath(
          routePointLatLng,
          closureLinePoints,
          false, // geodesic
          tolerance: 20, // 20-meter "bubble" around the line
        );

        if (isClose) {
          // This route is blocked! Show your existing warning.
          final bool? proceed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              // --- Your existing dialog code is perfect ---
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 24.0),
                title: Column(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade800,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Route Advisory',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: const Text(
                  'This route passes through a known road closure. This could be due to a landslide, event, or other hazard.\n\nAre you sure you want to continue?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    child: const Text("Proceed Anyway"),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    child: const Text("Cancel Route"),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              );
            },
          );
          // --- End of dialog ---

          return !(proceed ?? false);
        }
      }
    }

    return false; // No intersections found, route is clear.
  }

  Future<void> _updateNearbyPois() async {
    // 1. We need permission to get location
    if (!_locationPermissionGranted) {
      print("Nearby: Location permission not granted.");
      return;
    }

    Position? position;
    try {
      // 2. Get the user's current location
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5), // Don't hang forever
      );
    } catch (e) {
      print("Error getting location for 'Nearby' feature: $e");
      return; // Can't proceed
    }

    if (!mounted) return;
    final userLocation = LatLng(position.latitude, position.longitude);

    // 3. Use the cached POI list.
    if (_allPoiData.isEmpty) {
      print("Nearby: POI data is empty, skipping calculation.");
      return;
    }

    // 4. Calculate distances and filter
    final List<Map<String, dynamic>> nearbyList = [];
    for (final poi in _allPoiData) {
      final lat = poi['lat'] as double?;
      final lng = poi['lng'] as double?;

      if (lat != null && lng != null) {
        final double distance = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          lat,
          lng,
        );

        // 5. Set a radius (e.g., 2000 meters = 2km)
        if (distance <= 2000) {
          // Create a copy of the map and add the distance
          final newPoiData = Map<String, dynamic>.from(poi);
          newPoiData['distance'] = distance; // Add distance for sorting
          nearbyList.add(newPoiData);
        }
      }
    }

    // 6. Sort the list by distance (closest first)
    nearbyList.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    // 7. Update the state
    if (mounted) {
      setState(() {
        _nearbyPois = nearbyList;
      });
      print("Nearby: Updated list with ${_nearbyPois.length} places.");
    }
  }

  Future<void> _loadActiveItineraryStream() async {
    final prefs = await SharedPreferences.getInstance();
    final newActiveId = prefs.getString('activeItineraryId');
    // ⭐️ ADD THIS LINE
    final newActiveName = prefs.getString('activeItineraryName');
    final user = FirebaseAuth.instance.currentUser;

    if (newActiveId == _activeItineraryId && _activeItineraryStream != null) {
      return;
    }

    _activeItineraryStream?.listen(null).cancel();

    if (user != null && newActiveId != null) {
      if (mounted) {
        setState(() {
          _activeItineraryId = newActiveId;
          // ⭐️ ADD THIS LINE
          _activeItineraryName =
              newActiveName ?? 'My Itinerary'; // Save the name

          _activeItineraryStream = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('itineraries')
              .doc(_activeItineraryId)
              .collection('events')
              .where('eventTime', isGreaterThanOrEqualTo: Timestamp.now())
              .orderBy('eventTime')
              .snapshots();

          _activeItineraryStream?.listen(_updateHeadsUpEvent);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _activeItineraryId = null;
          _activeItineraryName = null; // ⭐️ ADD THIS LINE
          _activeItineraryStream = null;
          _activeHeadsUpEvent = null;
        });
      }
    }
  }

  Future<void> _showClearActiveTripDialog() async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Active Trip?'),
        content: Text(
            "Are you sure you want to remove '$_activeItineraryName' as your active trip?\n\nThis card will be hidden, and you'll need to set a new active trip from your itinerary list."),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (didConfirm == true) {
      await _clearActiveItinerary();
    }
  }

  /// Removes the active itinerary from SharedPreferences and updates the UI.
  Future<void> _clearActiveItinerary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeItineraryId');
    await prefs.remove('activeItineraryName');

    // Just call _loadActiveItineraryStream again. It will see the null ID
    // and automatically clear the state variables and hide the card.
    _loadActiveItineraryStream();
  }

// ⭐️ ADD THIS NEW HELPER FUNCTION ⭐️
  void _updateHeadsUpEvent(QuerySnapshot snapshot) {
    if (!mounted) return;

    final now = DateTime.now();
    DocumentSnapshot? eventForToday;
    if (snapshot.docs.isNotEmpty) {
      for (final doc in snapshot.docs) {
        final eventTime = (doc['eventTime'] as Timestamp).toDate();
        if (_isSameDay(eventTime, now)) {
          eventForToday = doc;
          break; // Found the first one for today
        }
      }
    }

    // Update the state
    setState(() {
      _activeHeadsUpEvent = eventForToday;
    });
  }

  // Ends navigation and hides the panel
  void _endNavigation() {
    _positionStreamSubscription?.cancel();

    setState(() {
      _clearPolylines(); // You should already have this function
      _panelState = NavigationPanelState.hidden;
      _navigationDetails = null;
      _lastDestination = null; // Forget the last destination
      _lastKnownPosition = null;
      _currentTransportRouteData = null; // 👈 ADD THIS LINE
      _itinerarySummary = null; // 👈 ADD THIS LINE
      _itineraryTitle = null;
      _itineraryEvents = [];
      _isItineraryRouteVisible = false; // 👈 ADD THIS LINE

      // Remove the route-specific markers
      _markers.removeWhere(
        (m) =>
            m.markerId.value == 'start_pin' ||
            m.markerId.value == 'end_pin' ||
            m.markerId.value == 'distance_marker' ||
            m.markerId.value.startsWith('itinerary_stop_') ||
            m.markerId.value == 'transport_start' ||
            m.markerId.value == 'transport_end',
      ); // Also remove distance marker
    });
  }

  int _parseDurationToMinutes(String durationText) {
    int totalMinutes = 0;
    // Regex to find numbers followed by "hour" or "min"
    final RegExp hourRegex = RegExp(r'(\d+)\s+(hour|hours)');
    final RegExp minRegex = RegExp(r'(\d+)\s+(min|mins)');

    final hourMatch = hourRegex.firstMatch(durationText);
    final minMatch = minRegex.firstMatch(durationText);

    if (hourMatch != null) {
      totalMinutes += (int.tryParse(hourMatch.group(1) ?? '0') ?? 0) * 60;
    }

    if (minMatch != null) {
      totalMinutes += int.tryParse(minMatch.group(1) ?? '0') ?? 0;
    }

    // Fallback for simple "25 min" strings that might not match
    if (totalMinutes == 0 &&
        (durationText.contains("min") || durationText.contains("mins"))) {
      try {
        return int.tryParse(durationText.split(" ").first) ?? 0;
      } catch (e) {
        print("Could not parse duration: $e");
        return 0;
      }
    }

    return totalMinutes;
  }

  /// Enters the immersive turn-by-turn navigation mode.
  void _enterLiveNavigation() {
    final List<Map<String, dynamic>>? steps =
        _navigationDetails?["steps"] as List<Map<String, dynamic>>?;

    if (steps == null || steps.isEmpty) {
      print("No steps found, cannot start navigation.");
      return;
    }

    setState(() {
      _navigationSteps = steps;
      _currentStepIndex = 0;
      _isNavigating = true;
      _panelState = NavigationPanelState.hidden;
      _isFollowingUser = true; // ⭐️ ADD THIS LINE
    });

    _updateNavigationStep(0, isFirstStep: true);

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) async {
      if (!_isNavigating || _currentStepIndex >= _navigationSteps.length)
        return;

      final userLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentSpeed = position.speed * 3.6;
      });

      // --- ⭐️ START OF MODIFICATION ⭐️ ---
      // --- Camera Logic (now conditional) ---
      double distanceMoved = 0;
      if (_lastKnownPosition != null) {
        distanceMoved = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }

      // Only animate the camera IF the user hasn't panned away
      if (_isFollowingUser) {
        if (_lastKnownPosition == null || distanceMoved > 3.0) {
          final newBearing =
              position.speed > 1 ? position.heading : _lastKnownBearing;

          // Set flag to prevent _onCameraMoveStarted from firing
          _isAnimatingCamera = true;
          _mapController
              ?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: userLocation,
                zoom: 17.5,
                tilt: 50.0,
                bearing: newBearing,
              ),
            ),
          )
              .then((_) {
            // Unset the flag after animation completes
            _isAnimatingCamera = false;
          });

          _lastKnownPosition = userLocation;
          _lastKnownBearing = newBearing;
        }
      } else {
        // If we are not following, just update the position
        // so the "recenter" button knows where to go
        _lastKnownPosition = userLocation;
      }
      // --- ⭐️ END OF MODIFICATION ⭐️ ---
      final LatLng currentStepEnd =
          _navigationSteps[_currentStepIndex]["end_location"];

      // Calculate distance to the end of this step
      final double distanceToStepEnd = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        currentStepEnd.latitude,
        currentStepEnd.longitude,
      );

      // Check if user is "close enough" to advance to the next step
      if (distanceToStepEnd < 20.0) {
        // 20-meter threshold
        setState(() {
          _currentStepIndex++;
        });
        _updateNavigationStep(_currentStepIndex);
      }
      // --- END STEP TRACKING ---

      // --- Recalculate Total (for bottom bar) ---
      if (_lastDestination != null) {
        final newDetails = await _getDirectionsDetails(
          userLocation,
          _lastDestination!,
          _currentTravelMode,
        );

        if (newDetails != null) {
          final int remainingMinutes =
              _parseDurationToMinutes(newDetails["duration"]);
          final newEta =
              DateTime.now().add(Duration(minutes: remainingMinutes));

          setState(() {
            _liveDistance = newDetails["distance"];
            _liveDuration = newDetails["duration"];
            _liveEta = DateFormat('h:mm a').format(newEta);
          });
        }
      }
    });
  }

  /// Exits the live navigation mode and returns to the overview.
  void _exitLiveNavigation() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    setState(() {
      _isNavigating = false;
      _isFollowingUser = false; // ⭐️ ADD THIS LINE
      _panelState = NavigationPanelState.expanded;
      _navigationSteps = [];
      _currentStepIndex = 0;
      _currentInstruction = "";
      _flutterTts.stop();
      _currentSpeed = 0.0;
    });

    _updateDistanceMarker(_liveDistance);

    if (_polylineCoordinates.isNotEmpty) {
      LatLngBounds bounds = _boundsFromLatLngList(_polylineCoordinates);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  void _clearPolylines() {
    setState(() {
      _polylines.clear();
      _polylineCoordinates.clear();
    });
  }

  /// Creates or updates the distance marker on the map.
  void _updateDistanceMarker(String distanceText) async {
    if (_polylineCoordinates.isEmpty) return;

    // Find the midpoint of the polyline to place the marker
    final LatLng markerPosition =
        _polylineCoordinates[_polylineCoordinates.length ~/ 2];

    // Create the custom marker from text
    final BitmapDescriptor markerIcon = await _createDistanceMarkerBitmap(
      distanceText,
    );

    final distanceMarker = Marker(
      markerId: const MarkerId('distance_marker'),
      position: markerPosition,
      icon: markerIcon,
      anchor: const Offset(0.5, 0.5), // Center the marker
    );

    setState(() {
      // Remove the old marker and add the new one
      _markers.removeWhere((m) => m.markerId.value == 'distance_marker');
      _markers.add(distanceMarker);
    });
  }

  /// Formats an instruction for display and speech.
  String _formatInstruction(String instruction) {
    if (instruction.isEmpty) return "";
    // Trim whitespace
    instruction = instruction.trim();
    // Capitalize the first letter
    String formatted = instruction[0].toUpperCase() + instruction.substring(1);
    // Ensure it ends with a period
    if (!formatted.endsWith('.') &&
        !formatted.endsWith('!') &&
        !formatted.endsWith('?')) {
      formatted += '.';
    }
    return formatted;
  }

  /// Sets the current instruction and speaks it
  void _updateNavigationStep(int stepIndex, {bool isFirstStep = false}) {
    if (stepIndex >= _navigationSteps.length) {
      // We've finished the last step
      final String arrivalMessage = "You have arrived at your destination.";
      setState(() {
        _currentInstruction = arrivalMessage;
      });

      if (!_isMuted) {
        _flutterTts.speak(_currentInstruction);
      }

      _exitLiveNavigation(); // Exit nav mode
      return;
    }

    // Get the current step's details
    final step = _navigationSteps[stepIndex];
    String instruction =
        step["instruction"]; // This is cleaned and has proper caps
    String distance = step["distance"];

    String instructionToDisplay;
    String instructionToSpeak;

    if (isFirstStep) {
      // For display, use Google's capitalized string
      instructionToDisplay = "$instruction for $distance.";
      // For speech, "Head..." sounds more natural
      instructionToSpeak = "Head $instruction and continue for $distance.";
    } else {
      // For all other steps, they are the same
      instructionToDisplay = instruction;
      instructionToSpeak = instruction;
    }

    setState(() {
      // Use the formatter to add a period, etc.
      _currentInstruction = _formatInstruction(instructionToDisplay);
    });

    if (!_isMuted) {
      // Speak the version *without* the extra punctuation
      _flutterTts.speak(instructionToSpeak);
    }
  }

  /// Displays a custom dialog with details about a road closure.
  void _showClosureDetails(Map<String, dynamic> closureData) {
    // --- START OF NEW DATA EXTRACTION ---
    // Get data with fallbacks
    final String name = closureData['name'] ?? 'Closure Information';
    final String type = closureData['type'] ?? 'Notice';
    final String details = closureData['details'] ?? 'No details provided.';
    String postedAtText = 'Report date not available.';

    // Check for 'postedAt' field instead of 'validUntil'
    if (closureData['postedAt'] != null &&
        closureData['postedAt'] is Timestamp) {
      final DateTime postedAt = (closureData['postedAt'] as Timestamp).toDate();
      // Format it to be readable
      postedAtText =
          'Reported on: ${DateFormat.yMMMd().add_jm().format(postedAt)}';
    }

    // Dynamically choose an icon and color based on the 'type'
    IconData closureIcon;
    Color iconColor;
    switch (type.toLowerCase()) {
      case 'landslide':
        closureIcon = Icons.warning_amber_rounded;
        iconColor = Colors.brown.shade600;
        break;
      case 'event':
        closureIcon = Icons.event;
        iconColor = Colors.blue.shade700;
        break;
      case 'construction':
        closureIcon = Icons.construction;
        iconColor = Colors.orange.shade800;
        break;
      default:
        closureIcon = Icons.traffic;
        iconColor = Colors.red.shade700;
    }
    // --- END OF NEW DATA EXTRACTION ---

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),

          // --- UPDATED TITLE SECTION ---
          title: Column(
            children: [
              Icon(
                closureIcon, // Use the new dynamic icon
                color: iconColor, // Use the new dynamic color
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                name, // e.g., "Landslide at Km. 55"
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // --- UPDATED CONTENT SECTION ---
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Type" Chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  type.toUpperCase(), // e.g., "LANDSLIDE"
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // "Details"
              Text(
                details, // e.g., "Road is completely impassable..."
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // "Posted At"
              Text(
                postedAtText, // e.g., "Reported on: Nov 5, 2025..."
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ),

          // --- (Button is the same) ---
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                child: const Text('Okay, Got It'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _recenterLiveNavigation() {
    if (_lastKnownPosition == null) return;

    setState(() {
      _isFollowingUser = true;
    });

    // Animate back to the user's position
    _isAnimatingCamera = true;
    _mapController
        ?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _lastKnownPosition!,
          zoom: 17.5,
          tilt: 50.0,
          bearing: _lastKnownBearing, // Use the last known bearing
        ),
      ),
    )
        .then((_) {
      _isAnimatingCamera = false;
    });
  }

  // === UI ===
  @override
  Widget build(BuildContext context) {
    final double paddingTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraMoveStarted: _onCameraMoveStarted,

            // Update the current zoom level as the user moves the map
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },

            // When the user stops moving the map, rebuild the markers
            onCameraIdle: () {
              _rebuildMarkers();
            },

            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines.union(_closureLines),
            polygons: {},
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false, // Hide compass during immersive navigation
          ),
          if (_activeHeadsUpEvent != null &&
              !_isNavigating &&
              !_isItineraryRouteVisible)
            _buildHeadsUpCard(_activeHeadsUpEvent!),
          // --- PASTE THE COMPASS WIDGET HERE AND UPDATE IT ---
          // --- Compass Widget (now animated) ---
          AnimatedPositioned(
            // ⭐️ --- START OF NEW LOGIC --- ⭐️
            top: (_isNavigating && _currentInstruction.isNotEmpty)
                ? (paddingTop + 120) // Pushed down by turn-by-turn banner
                : (_activeHeadsUpEvent != null &&
                        !_isNavigating &&
                        !_isItineraryRouteVisible)
                    ? (paddingTop + 175) // Pushed down by heads-up card
                    : (paddingTop + 70), // Default position
            // ⭐️ --- END OF NEW LOGIC --- ⭐️
            right: 12,
            duration: const Duration(milliseconds: 300), // Animation duration
            curve: Curves.easeInOut, // Animation curve
            child: CompassWidget(),
          ),
          // --- END OF COMPASS FIX ---

          // --- ITINERARY-SPECIFIC UI (Only visible when itinerary route is active) ---
          if (_isItineraryRouteVisible) ...[
            // The Summary Panel
            _buildItinerarySummaryPanel(),

            // The Close Button
            Positioned(
              top: paddingTop + 130, // Position it below the compass
              right: 16,
              child: _buildClearItineraryButton(),
            ),
          ],

          // --- STANDARD UI (Hidden when itinerary route is active) ---
          if (!_isItineraryRouteVisible) ...[
            // The top bar with profile, filter, and search
            if (!_isNavigating)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // User Profile Button
                          _buildProfileButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder: (context) => ProfileMenu(
                                  userData: _userData,
                                  // Pass the new function signature
                                  onDrawItinerary:
                                      (Map<String, dynamic> itineraryData) {
                                    _drawItineraryRoute(itineraryData);
                                  },
                                ),
                              );
                            },
                          ),
                          // Dropdown filter
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ), // A bit more padding
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedFilter,
                                  isExpanded: true,
                                  // Use a themed dropdown arrow
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  onChanged: _onFilterChanged,

                                  // This builder customizes the look of the COLLAPSED button
                                  selectedItemBuilder: (BuildContext context) {
                                    return _filters.map<Widget>((String item) {
                                      return Row(
                                        children: [
                                          _getIconForFilter(item),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              item,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList();
                                  },

                                  // This builder customizes the look of the items in the EXPANDED list
                                  items: _filters.map((String item) {
                                    return DropdownMenuItem<String>(
                                      value: item,
                                      child: Row(
                                        children: [
                                          _getIconForFilter(item),
                                          const SizedBox(width: 10),
                                          Text(item),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                          // Search button
                          _buildRoundButton(
                            icon: Icons.search,
                            onPressed: () async {
                              final result =
                                  await showSearch<Map<String, dynamic>?>(
                                context: context,
                                delegate: POISearchDelegate(
                                  userLocation: _lastKnownPosition,
                                ),
                              );
                              if (result != null) {
                                final lat = result['lat'] as double?;
                                final lng = result['lng'] as double?;
                                if (lat != null && lng != null) {
                                  const double latOffset = 0.0012;
                                  await _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(lat + latOffset, lng),
                                      16,
                                    ),
                                  );
                                  Future.delayed(
                                    const Duration(milliseconds: 300),
                                    () {
                                      _showPoiSheet(
                                        name: result['name'] ?? 'Unnamed',
                                        description:
                                            result['description'] ?? '',
                                        data: result,
                                      );
                                    },
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // The column of floating action buttons on the right
            if (!_isNavigating)
              Positioned(
                bottom: 120,
                right: 16,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Show buttons ONLY if the nav panel is also hidden
                    if (_panelState == NavigationPanelState.hidden) ...[
                      // Transport Options Button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: _currentTransportRouteData == null
                            ? FloatingActionButton(
                                key: const ValueKey('transport_button'),
                                heroTag: 'transport_button',
                                onPressed: _showTransportBrowser,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.directions_bus,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),

                      // Custom Route Button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: _currentTransportRouteData == null
                            ? FloatingActionButton(
                                key: const ValueKey('route_button'),
                                heroTag: 'route_button',
                                onPressed: _showCustomRouteSheet,
                                backgroundColor: Theme.of(context).primaryColor,
                                child: const Icon(
                                  Icons.directions,
                                  color: Colors.white,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildLocationButton(),
                    const SizedBox(height: 12),
                    if (_panelState == NavigationPanelState.hidden)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: _currentTransportRouteData == null
                            ? _buildMapStyleButton()
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),

            // Discover Places Panel
            if (!_isNavigating &&
                _panelState == NavigationPanelState.hidden &&
                _currentTransportRouteData == null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: DiscoveryPanel(
                  nearbyPois: _nearbyPois,
                  onPoiSelected: (poiData) => _showPoiSheet(
                    name: poiData['name'] ?? '',
                    description: poiData['description'] ?? '',
                    data: poiData,
                  ),
                ),
              ),
          ],

          // --- ADD THIS WIDGET ---
          // Shows the details for the selected transport route
          // This will appear *instead* of the DiscoveryPanel
          if (_currentTransportRouteData != null && !_isNavigating)
            _buildTransportRouteDetailsCard(),
          // --- END OF ADDITION ---

          // --- ⭐️ ADD THIS WIDGET ⭐️ ---
          // Shows the speedometer during driving navigation
          _buildSpeedIndicator(),
          // --- END OF ADDITION ---
          // --- ⭐️ ADD THIS WIDGET ⭐️ ---
          // This is the new "Recenter" button
          if (_isNavigating &&
              !_isFollowingUser) // Only show if navigating AND not following
            Positioned(
              bottom: 160, // Same level as the speedometer
              right: 16, // On the opposite side
              child: FloatingActionButton(
                heroTag: 'recenter_button',
                onPressed: _recenterLiveNavigation,
                backgroundColor: Colors.white,
                child: Icon(Icons.my_location, color: Colors.blue.shade700),
              ),
            ),
          // --- ⭐️ END OF ADDITION ⭐️ ---
          // --- NAVIGATION UI (Overlays everything else) ---
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isNavigating
                ? _buildLiveNavigationUI()
                : _buildNavigationPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18, color: const Color(0xFF3A6A55)),
      label: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey.shade800),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
      backgroundColor: Colors.grey.shade200,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final bool isOpen = status.toLowerCase() == 'open';
    final Color statusColor =
        isOpen ? Colors.green.shade700 : Colors.red.shade700;
    final IconData statusIcon =
        isOpen ? Icons.check_circle_outline : Icons.highlight_off_outlined;

    return Chip(
      avatar: Icon(statusIcon, size: 18, color: statusColor),
      label: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey.shade800),
          children: [
            const TextSpan(
              text: 'Status: ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: status,
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
            ),
          ],
        ),
      ),
      backgroundColor: statusColor.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
    );
  }

  Widget _getIconForFilter(String filter) {
    IconData iconData;
    Color iconColor = Colors.grey.shade700; // Default color

    if (filter == _selectedFilter) {
      iconColor =
          Theme.of(context).primaryColor; // Use primary color for selected item
    }

    switch (filter) {
      case 'Tourist Spots':
        iconData = Icons.landscape_outlined;
        break;
      case 'Business Establishments':
        iconData = Icons.store_outlined;
        break;
      case 'Accommodations':
        iconData = Icons.hotel_outlined;
        break;
      case 'Transport Terminals':
        iconData = Icons.directions_bus_outlined;
        break;
      case 'Agencies and Offices':
        iconData = Icons.corporate_fare_outlined;
        break;
      default: // For 'All'
        iconData = Icons.map_outlined;
    }
    return Icon(iconData, color: iconColor);
  }

  Widget _buildNavigationPanel() {
    switch (_panelState) {
      case NavigationPanelState.expanded:
        return _buildExpandedPanel();
      case NavigationPanelState.minimized:
        return _buildMinimizedPanel();
      case NavigationPanelState.hidden:
        return const SizedBox.shrink(); // An empty widget
    }
  }

  /// The small, minimized panel at the bottom-left of the screen
  Widget _buildMinimizedPanel() {
    if (_navigationDetails == null) return const SizedBox.shrink();

    // Using Align for cleaner positioning
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () =>
                setState(() => _panelState = NavigationPanelState.expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Keep the card compact
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ETA: ${_navigationDetails!["duration"]}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text('Show details'),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Close button is now outside the tap area for details
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.red,
                    onPressed: _endNavigation,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The full-details panel sliding up from the bottom
  /// The full-details panel sliding up from the bottom (Detailed Layout)
  Widget _buildExpandedPanel() {
    if (_navigationDetails == null) return const SizedBox.shrink();

    final Color themeColor = const Color(0xFF3A6A55);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(blurRadius: 15, color: Colors.black.withOpacity(0.2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Route Details",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 28,
                  ),
                  onPressed: () => setState(
                    () => _panelState = NavigationPanelState.minimized,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // --- ⭐️ START OF ADDITION ⭐️ ---
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.trip_origin, // Different icon for start
                color: Colors.grey.shade600,
              ),
              title: const Text(
                "Starting Point",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _navigationDetails!["startAddress"] ?? "Loading...",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // --- ⭐️ END OF ADDITION ⭐️ ---

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.location_on,
                color: themeColor,
              ),
              title: const Text(
                "Destination",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _navigationDetails!["endAddress"] ?? "Loading address...",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            if (_isRouteLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                    color: themeColor,
                  ),
                ),
              )
            else
              Row(
                children: [
                  _buildInfoChip(Icons.map, _liveDistance),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.timer, _liveDuration),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildModeButton(
                  "Driving",
                  Icons.directions_car,
                  "driving",
                  _updateRoute,
                ),
                _buildModeButton(
                  "Walking",
                  Icons.directions_walk,
                  "walking",
                  _updateRoute,
                ),
                _buildModeButton(
                  "Cycling",
                  Icons.directions_bike,
                  "bicycling",
                  _updateRoute,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _endNavigation,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      _isCustomRoutePreview ? "Clear Route" : "Cancel",
                    ),
                  ),
                ),
                if (!_isCustomRoutePreview) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _enterLiveNavigation,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text("Start"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper for the small mode icons

  // Helper for the Distance and Duration chips
  Widget _buildInfoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Refactored travel mode button
  Widget _buildModeButton(
    String label,
    IconData icon,
    String mode,
    Function(String) onPressed,
  ) {
    final bool isSelected = _currentTravelMode == mode;
    return Column(
      children: [
        InkWell(
          onTap: () => onPressed(mode),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey[200],
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.blueAccent, width: 2)
                  : null,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black54,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle, // Match the shape of the CircleAvatar
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        radius: 24,
        child: IconButton(
          icon: Icon(icon, color: Colors.black87),
          onPressed: onPressed,
        ),
      ),
    );
  }

  // REPLACE your _buildProfileButton with this cleaner version
  Widget _buildProfileButton({required VoidCallback onPressed}) {
    final photoUrl = _userData?['profilePictureUrl'];
    final fullName = _userData?['fullName'] ?? '';

    Widget avatarContent; // This will hold the specific avatar

    if (photoUrl != null && photoUrl.isNotEmpty) {
      // Case 1: User has a profile picture
      avatarContent = CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade300,
        // --- CHANGE THIS LINE ---
        backgroundImage: CachedNetworkImageProvider(photoUrl),
      );
    } else if (fullName.isNotEmpty) {
      // Case 2: No picture, but has a name
      avatarContent = CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          fullName[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      // Case 3: No data at all
      avatarContent = CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade400,
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    // Now, wrap the final avatarContent in the shadow container and gesture detector
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(onTap: onPressed, child: avatarContent),
    );
  }

  // REPLACE your _buildMapStyleButton with this
  Widget _buildMapStyleButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        radius: 24,
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.layers, color: Colors.black87),
          onSelected: (value) {
            switch (value) {
              case 'Default':
                _setMapStyle('map_style.json');
                break;
              case 'Clean':
                _setMapStyle('clean.json');
                break;
              case 'Tourism':
                _setMapStyle('tourism.json');
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'Default', child: Text('Default')),
            PopupMenuItem(value: 'Clean', child: Text('Clean')),
            PopupMenuItem(value: 'Tourism', child: Text('Tourism')),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveNavigationUI() {
    return Stack(
      children: [
        // --- THIS IS THE CHANGE ---
        _buildTurnByTurnBanner(), // The new top banner
        _buildNavigationInfoBar(), // The existing bottom bar
        // --- END OF CHANGE ---
      ],
    );
  }

  // Add this new helper widget to your _MapScreenState
  Widget _buildNavigationInfoBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        margin: const EdgeInsets.all(12),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12), // Adjusted padding
          child: Row(
            children: [
              // --- ⭐️ START OF NEW LAYOUT ⭐️ ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Row 1: Time and Distance ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _liveDuration, // Live duration
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ETA: $_liveEta', // Live ETA
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.green),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            _liveDistance, // Live distance
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, thickness: 1),

                    // --- Row 2: Start Address ---
                    Row(
                      children: [
                        Icon(Icons.trip_origin,
                            color: Colors.grey.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            // Use the data from navigationDetails
                            _navigationDetails?["startAddress"] ??
                                "Starting Point",
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // --- Row 3: End Address ---
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Theme.of(context).primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            // Use the data from navigationDetails
                            _navigationDetails?["endAddress"] ?? "Destination",
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8), // Spacer
              // --- ⭐️ END OF NEW LAYOUT ⭐️ ---

              // Exit Button (remains the same)
              ElevatedButton(
                onPressed: _exitLiveNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ADD THIS WIDGET INSIDE YOUR _MapScreenState
  Widget _buildLocationButton() {
    IconData icon;
    Color iconColor = Colors.grey.shade700;
    Color backgroundColor = Colors.white;

    switch (_locationButtonState) {
      case LocationButtonState.centered:
        icon = Icons.my_location;
        iconColor = Colors.white;
        backgroundColor = Colors.blue;
        break;
      case LocationButtonState.compass:
        icon = Icons.explore; // Compass icon
        iconColor = Colors.white;
        backgroundColor = Colors.blue;
        break;
      case LocationButtonState.navigating:
        icon = Icons.navigation_rounded;
        iconColor = Colors.white;
        backgroundColor = Colors.blue;
        break;
      case LocationButtonState.offCenter:
        icon = Icons.my_location;
        break;
    }

    return FloatingActionButton(
      heroTag: 'location_button',
      onPressed: _goToMyLocation,
      backgroundColor: backgroundColor,
      child: Icon(icon, color: iconColor),
    );
  }

  Widget _buildClearItineraryButton() {
    return FloatingActionButton.small(
      heroTag: 'clear_itinerary_button',
      onPressed: _endNavigation, // This button's only job is to clean up
      backgroundColor: Colors.white,
      child: Icon(Icons.close, color: Colors.grey.shade700),
    );
  }

  // ⭐️ REPLACE the old panel with this new DraggableScrollableSheet ⭐️
  Widget _buildItinerarySummaryPanel() {
    if (_itinerarySummary == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      initialChildSize: 0.25, // Start partially expanded
      minChildSize: 0.15, // Can be minimized
      maxChildSize: 0.8, // Can be dragged up
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24.0)),
            boxShadow: [
              BoxShadow(
                blurRadius: 10.0,
                color: Colors.black.withOpacity(0.2),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // --- 1. The Grab Handle ---
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // --- 2. Title and Summary ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _itineraryTitle ?? 'My Itinerary', // Use the new title
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildItineraryInfoChip(
                          Icons.timer_outlined,
                          _itinerarySummary!['duration']!,
                          "Total Travel Time", // New label
                        ),
                        const SizedBox(width: 12),
                        _buildItineraryInfoChip(
                          Icons.map_outlined,
                          _itinerarySummary!['distance']!,
                          "Total Distance",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 24.0, thickness: 1.0),

              // --- 3. The Event List ---
              ...List.generate(_itineraryEvents.length, (index) {
                final event = _itineraryEvents[index];
                final time = (event['time'] as Timestamp).toDate();

                int? markerNum;
                if (event['coordinates'] != null) {
                  markerNum = _itineraryEvents
                      .sublist(0, index + 1)
                      .where((e) => e['coordinates'] != null)
                      .length;
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: markerNum != null
                        ? Colors.orange.shade700
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    child: Text(
                      markerNum != null ? '$markerNum' : '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    event['name'] ?? 'Event',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    DateFormat.jm().format(time),
                  ),
                );
              }),
              const SizedBox(height: 20), // Add padding at the bottom
            ],
          ),
        );
      },
    );
  }
  // In lib/screens/map_homescreen.dart -> _MapScreenState

  /// A new widget to display transport route details at the bottom of the screen.
  Widget _buildTransportRouteDetailsCard() {
    if (_currentTransportRouteData == null) return const SizedBox.shrink();

    final route = _currentTransportRouteData!;
    final String vehicleType = route['routeName'] ?? 'Transport';
    final String fare = route['fareDetails'] ?? 'N/A';
    final String schedule = route['schedule'] ?? 'N/A';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Card(
        margin: const EdgeInsets.all(12.0),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Adjusted padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- FIX 1: Title and Close Button in one Row ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Route: $vehicleType",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  // --- FIX 1: Move the close button here ---
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _endNavigation, // Re-use existing function
                  ),
                ],
              ),
              // --- FIX 2: Use ListTiles for readable text ---
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.money_outlined, color: Colors.green),
                title: const Text("Fare Details",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(fare), // Text will wrap automatically
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.schedule_outlined, color: Colors.blue),
                title: const Text("Schedule",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(schedule), // Text will wrap automatically
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurnByTurnBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12.0,
      left: 12.0,
      right: 12.0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentInstruction.isEmpty
            ? const SizedBox.shrink()
            : Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme.of(context).primaryColor,
                child: Padding(
                  // --- ADJUST PADDING ---
                  padding: const EdgeInsets.only(
                      left: 16.0, right: 8.0, top: 8.0, bottom: 8.0),
                  // --- START OF FIX: Use a Row ---
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _currentInstruction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // --- The new mute button ---
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            if (!_isMuted) {
                              // Speak current instruction if unmuting
                              _flutterTts.speak(_currentInstruction);
                            } else {
                              _flutterTts.stop();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  // --- END OF FIX ---
                ),
              ),
      ),
    );
  }

  /// Builds the speed indicator widget.
  Widget _buildSpeedIndicator() {
    // Only show if navigating AND driving
    if (!_isNavigating || _currentTravelMode != "driving") {
      return const SizedBox.shrink();
    }

    return Positioned(
      // --- ⭐️ THIS IS THE FIX ⭐️ ---
      // We increased 120 to 160 to lift it
      // above the new, taller navigation bar.
      bottom: 160,
      // --- ⭐️ END OF FIX ⭐️ ---
      left: 12,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentSpeed.toStringAsFixed(0), // The speed
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "km/h",
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _closureSub;

  void _listenToClosures() {
    _closureSub?.cancel();
    _closureSub = FirebaseFirestore.instance
        .collection('roadClosures')
        .snapshots()
        .listen((snapshot) {
      // We are now creating a Set of Polylines
      Set<Polyline> newLines = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> areaPoints = data['area'] ?? [];

        // We assume 'area' now contains 2 points (start/end)
        if (areaPoints.isNotEmpty) {
          final List<LatLng> lineCoords = areaPoints.map((point) {
            if (point is GeoPoint) {
              return LatLng(point.latitude, point.longitude);
            } else if (point is Map) {
              return LatLng(
                  point['latitude'] ?? 0.0, point['longitude'] ?? 0.0);
            }
            return const LatLng(0, 0);
          }).toList();

          // Create a Polyline instead of a Polygon
          newLines.add(
            Polyline(
              polylineId: PolylineId(doc.id),
              points: lineCoords,
              color: Colors.red.shade700,
              width: 6, // Make it nice and thick
              // Make it dashed to show it's a closure
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              consumeTapEvents: true,
              onTap: () {
                _showClosureDetails(data); // Your existing dialog function
              },
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          // Update the new state variable
          _closureLines = newLines;
        });
      }
    }, onError: (error) {
      print("❌ ERROR in closure listener: $error");
    });
  }

  Widget _buildItineraryInfoChip(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
        dateA.month == dateB.month &&
        dateA.day == dateB.day;
  }

  Widget _buildHeadsUpCard(DocumentSnapshot eventDoc) {
    final event = eventDoc.data() as Map<String, dynamic>;
    final eventTime = (event['eventTime'] as Timestamp).toDate();
    final String eventName = event['destinationPoiName'] ?? 'Event';
    final String itineraryName = event['itineraryName'] ?? 'Active Trip';
    final String timeAgo = timeago.format(eventTime);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 70, // Below the search bar
      left: 12,
      right: 12,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withAlpha(220),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 30,
            ),
            title: Text(
              'Up Next: $eventName',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              'From: $itineraryName • ($timeAgo)',
              style: const TextStyle(color: Colors.white70),
            ),
            // ⭐️ --- ADD THIS TRAILING WIDGET --- ⭐️
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _showClearActiveTripDialog,
              tooltip: 'Clear active trip',
            ),
            // ⭐️ --- END OF ADDITION --- ⭐️
          ),
        ),
      ),
    );
  }
}
