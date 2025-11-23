// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
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
import 'itinerary_detail_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/tour_guide_model.dart';
import '../widgets/navigation_overlay.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/heads_up_card.dart';
import '../widgets/transport_details_card.dart';
import '../widgets/closure_alert_dialog.dart';
import '../widgets/poi_tip_card.dart';
import '../services/route_service.dart';
import '../services/user_data_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/responsible_tourism_dialog.dart';
import '../widgets/enable_location_dialog.dart';
import '../widgets/guide_card.dart';
import 'package:flutter/foundation.dart';

enum LocationButtonState {
  centered,
  offCenter,
  navigating,
  compass,
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

String _currentTravelMode = "driving"; // driving by default
LatLng? _lastDestination; // remember last POI clicked

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  // ⭐️ NEW: Keys for Feature Discovery
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _transportKey = GlobalKey();
  final Map<int, BitmapDescriptor> _cachedNumberedMarkers = {};
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
  MapType _currentMapType = MapType.normal; // Start with the default view
  // --- START: ADD FOR TURN-BY-TURN ---
  final RouteService _routeService = RouteService();
  final MarkerService _markerService = MarkerService();
  final UserDataService _userDataService = UserDataService();
  late FlutterTts _flutterTts; // The TTS engine
// ⭐️ NEW: For Offline Mode
  bool _isOffline = false;
  // ignore: unused_field
  StreamSubscription? _connectivitySubscription;
  // ⭐️ NEW: Track previous offline state for "Restored" message
  bool _wasOffline = false;

  // ⭐️ NEW: Track if GPS is physically enabled on the phone
  bool _isLocationServiceEnabled = false;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  // ⭐️ NEW: For Out-of-Bounds Warning
  bool _showRecenterButton = false;
  // Define Sagada Bounds (Rough box around the municipality)
  final LatLngBounds _sagadaBounds = LatLngBounds(
    southwest: const LatLng(17.05, 120.85),
    northeast: const LatLng(17.13, 120.95),
  );

  // ⭐️ --- START OF NEW "HEADS-UP" VARIABLES --- ⭐️
  Stream<QuerySnapshot>? _activeItineraryStream;
  String? _activeItineraryId;
  String? _activeItineraryName; // ⭐️ ADD THIS LINE
  DocumentSnapshot? _activeHeadsUpEvent;
  Timer? _headsUpTimer;
  // ⭐️ --- END OF NEW "HEADS-UP" VARIABLES --- ⭐️
  List<Map<String, dynamic>> _navigationSteps = []; // Holds all steps
  int _currentStepIndex = 0; // Tracks which step we are on
  String _currentInstruction = ""; // The text to display and speak
  bool _isMuted = false; // 👈 ADD THIS
  double _currentSpeed = 0.0; // 👈 ADD THIS
  List<Map<String, dynamic>> _nearbyPois = []; // 👈 ADD THIS LINE
  // --- END: ADD FOR TURN-BY-TURN ---
  TourGuide? _activeTourGuide; // Stores the current guide for the active trip
  String?
      _highlightedPoiId; // ⭐️ NEW: Store the ID of the currently highlighted POI ⭐️
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
    'Food & Dining', // ⭐️ ADD THIS
    'Business Establishments',
    'Accommodations',
    'Transport Terminals',
    'Agencies and Offices',
    'Services',
    'Parking',
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
    // 🚀 OPTIMIZATION: Return cached version if it exists
    if (_cachedNumberedMarkers.containsKey(number)) {
      return _cachedNumberedMarkers[number]!;
    }
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

// 🚀 OPTIMIZATION: Save to cache before returning
    final bitmap = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
    _cachedNumberedMarkers[number] = bitmap;
    return bitmap;
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

    final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

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

        // 1. Check for closures using the Service
        bool isBlocked =
            _routeService.isRouteBlocked(mainRoutePoints, _closureLines);

        if (isBlocked) {
          // 2. Show the warning dialog (using the helper we added in Step 8)
          final bool proceed = await _showClosureWarningDialog();

          // 3. If user cancels, stop drawing
          if (!proceed) {
            _endNavigation();
            return;
          }
        }
        allPolylines.add(
          Polyline(
            polylineId: const PolylineId("itinerary_route_main"),
            color: Colors.orange.shade700,
            width: 6,
            points: mainRoutePoints,

            // ⭐️ NEW: Add Tap Interaction ⭐️
            consumeTapEvents: true,
            onTap: () {
              // Ensure we have a summary before displaying
              if (_itinerarySummary != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Route Summary: ${_itinerarySummary!['distance']} | ${_itinerarySummary!['duration']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior
                        .floating, // Floating style looks cleaner
                  ),
                );
              }
            },
            // ⭐️ END of Tap Interaction ⭐️
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
                zIndex: 3,
              ),
            );
            markerNum++;
          }
        }

        // Update the state
        setState(() {
          _polylines = allPolylines;
          // ⭐️ FIX: Use "=" instead of "addAll" to WIPE old markers ⭐️
          _markers = numberedMarkers;
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
    if (_mapController == null) return;

    // 🚀 OPTIMIZATION: Get the current visible boundaries of the map
    final LatLngBounds visibleRegion = await _mapController!.getVisibleRegion();

    // 1. Determine if we are in a mode that requires "Clutter Reduction"
    final bool useStrictFiltering =
        _isItineraryRouteVisible || _currentTransportRouteData != null;

    List<Map<String, dynamic>> visiblePois;

    // 🚀 OPTIMIZATION: Filter _allPoiData to only include points inside the screen
    // We use a simple helper function check (defined below)
    final List<Map<String, dynamic>> pointsOnScreen = _allPoiData.where((p) {
      final lat = p['lat'] as double?;
      final lng = p['lng'] as double?;
      if (lat == null || lng == null) return false;

      return visibleRegion.contains(LatLng(lat, lng));
    }).toList();

    if (useStrictFiltering) {
      // Use the reduced list
      visiblePois =
          pointsOnScreen.where((p) => p['type'] == 'Tourist Spots').toList();
    } else {
      if (_selectedFilter != 'All') {
        // Use the reduced list
        visiblePois = pointsOnScreen;
      } else {
        // Pass the reduced list to your smart zoom logic
        visiblePois = _markerService.filterPoisByZoom(
          allPois: pointsOnScreen, // <-- Pass filtered list here
          zoomLevel: _currentZoom,
        );
      }
    }

    // 2. Create the markers for these visible POIs
    final Set<Marker> normalMarkers = await _markerService.createMarkers(
      poiList: visiblePois,
      zoomLevel: _currentZoom,
      onTap: (data) {
        // 🚀 NEW: Animate Camera on Tap
        final lat = data['lat'] as double?;
        final lng = data['lng'] as double?;
        if (lat != null && lng != null) {
          _focusOnPoi(lat, lng);
        }

        _showPoiSheet(
          name: data['name'] ?? 'Unnamed',
          description: data['description'] ?? 'No description available.',
          data: data,
        );
      },
      highlightedId: _highlightedPoiId,
    );

    // 3. Preserve existing Route Markers
    final Set<Marker> routeMarkers = _markers.where((m) {
      final id = m.markerId.value;
      return id == 'start_pin' ||
          id == 'end_pin' ||
          id == 'distance_marker' ||
          id.startsWith('itinerary_stop_') ||
          id == 'transport_start' ||
          id == 'transport_end';
    }).toSet();

    // 4. Merge them!
    if (mounted) {
      setState(() {
        _markers = normalMarkers.union(routeMarkers);
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

// This is the new, cleaner _drawRoute function
  Future<bool> _drawRoute(
    LatLng origin,
    LatLng destination,
    String mode,
  ) async {
    _lastDestination = destination;

    // 1. Use the Service to fetch the route
    final routeData = await _routeService.getRoutePolyline(
      origin: origin,
      destination: destination,
      mode: mode,
    );

    if (routeData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No route available for $mode mode here.")),
      );
      return false;
    }

    _polylineCoordinates = routeData['points'];

    // 2. Use the Service to check for closures
    // Note: We pass _closureLines (which is a Set<Polyline>)
    bool isBlocked = _routeService.isRouteBlocked(
      _polylineCoordinates,
      _closureLines,
    );

    if (isBlocked) {
      // Show the warning dialog
      final bool proceed = await _showClosureWarningDialog();
      if (!proceed) {
        _endNavigation();
        return false;
      }
    }

    // 3. Create the Polylines (Visuals)
    final Set<Polyline> polylines = {};

    // Main on-road segment
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

    // Check if the destination is off-road (last mile)
    if (_polylineCoordinates.isNotEmpty) {
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
    }

    // 4. Icons & State Update
    final BitmapDescriptor startIcon = await _createCircleMarkerBitmap(
      Colors.green.shade600,
    );
    final BitmapDescriptor endIcon = await _createCircleMarkerBitmap(
      Colors.blue.shade600,
    );

    setState(() {
      _polylines = polylines;
      _markers.add(
        Marker(
          markerId: const MarkerId('start_pin'),
          position: origin,
          icon: startIcon,
          anchor: const Offset(0.5, 0.5),
          zIndex: 3,
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

    // 5. Animate Camera
    if (routeData['bounds_data'] != null) {
      // Ideally we use bounds from API, but for now we can stick to your existing helper
      // or use the bounds_data if you want to parse it.
      // Let's keep your existing helper for consistency:
      LatLngBounds bounds = _boundsFromLatLngList([
        origin,
        destination,
        ..._polylineCoordinates,
      ]);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }

    return true;
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

  Future<Map<String, dynamic>?> _getDirectionsDetails(
    LatLng origin,
    LatLng destination,
    String mode,
  ) async {
    // Delegates entirely to the service
    return await _routeService.getDirectionsDetails(
      origin: origin,
      destination: destination,
      mode: mode,
    );
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

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ResponsibleTourismDialog(isGuideRequired: isGuideRequired);
      },
    );
  }

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
    _compassSubscription = null;
    if (resetBearing) {
      _isAnimatingCamera = true;
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _lastKnownPosition ?? _initialPosition,
            zoom: 16,
            bearing: 0,
            tilt: 45.0, // ⭐️ Change from 0 to 45.0
          ),
        ),
      );
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
            width: 4,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            points: _polylineCoordinates,
            consumeTapEvents: true,
            onTap: () {
              print("Polyline for '${routeData['routeName']}' was tapped!");
              // This should call your existing dialog function
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
    _flutterTts = FlutterTts();

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _currentUser = user;
      });
      if (user != null) {
        // ⭐️ MAKE SURE THIS LINE IS HERE ⭐️
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

    // ⭐️ --- ADD THIS TIMER --- ⭐️
    // This will periodically re-check the itinerary stream
    _headsUpTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        // This will force the stream to re-query Firestore with a new Timestamp.now()
        _loadActiveItineraryStream(forceReload: true);
      }
    });
    // ⭐️ --- END OF ADDITION --- ⭐️

    // ⭐️ 1. Listen for Internet Connection changes
    _checkConnectivity();

    // ⭐️ 2. Schedule Feature Discovery (Coach Marks)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFeatureDiscovery();
    });
    // ⭐️ NEW: Listen for GPS Service Changes (On/Off)
    _checkInitialLocationService();
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        setState(() {
          _isLocationServiceEnabled = (status == ServiceStatus.enabled);
        });
      },
    );
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
      (DocumentSnapshot snapshot) async {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _userData = data;
          });

          final photoUrl = data['profilePictureUrl'] as String?;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            precacheImage(NetworkImage(photoUrl), context);
          }

          // ⭐️ THIS BLOCK IS WHAT REFERENCES YOUR MISSING VARIABLES ⭐️
          if (!_welcomeMessageShown) {
            _welcomeMessageShown = true;

            // 1. Welcome Toast
            await _showWelcomeToast(data);

            // 2. Tourism Reminder (References _tourismReminderShown & _showResponsibleTourismReminder)
            if (mounted && !_tourismReminderShown) {
              await _showResponsibleTourismReminder();
              setState(() {
                _tourismReminderShown = true;
              });
            }

            // 3. Location Check (References _checkLocationOnStartup)
            if (mounted) {
              await _checkLocationOnStartup();
            }

            // ⭐️ NEW: Trigger Feature Discovery Tutorial ⭐️
            if (mounted) {
              // Small delay to ensure previous dialogs are fully closed/rendered
              Future.delayed(const Duration(milliseconds: 500), () {
                TutorialService.showTutorial(
                  context: context,
                  searchKey: _searchKey,
                  filterKey: _filterKey,
                  transportKey: _transportKey,
                );
              });
            }

            // 4. Go to Location
            if (mounted) {
              await _goToMyLocation();
            }
          }
          // ⭐️ END OF BLOCK ⭐️
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
    _headsUpTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSubscription?.cancel(); // ⭐️ Cancel this

    super.dispose();
  }

  // ⭐️ --- ADD THIS ENTIRE FUNCTION --- ⭐️
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // This checks if the user has returned to the app
    if (state == AppLifecycleState.resumed) {
      print("App resumed: Checking for new active itinerary...");
      // ⭐️ --- MODIFIED THIS LINE --- ⭐️
      // Force a re-check of SharedPreferences
      _loadActiveItineraryStream(forceReload: true);
    }
  }
  // ⭐️ --- END OF NEW FUNCTION --- ⭐️

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;

    final prefs = await SharedPreferences.getInstance();
    // 1. Get the saved style (could be 'tourism.json' OR 'satellite')
    final savedStyle = prefs.getString('mapStyle') ?? 'tourism.json';

    if (savedStyle == 'satellite') {
      // 2. If 'satellite', switch the mode and DON'T load JSON
      setState(() {
        _currentMapType = MapType.satellite;
      });
    } else {
      // 3. If normal/tourism, ensure mode is normal AND load JSON
      setState(() {
        _currentMapType = MapType.normal;
      });
      _setMapStyle(savedStyle);
    }
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

  // ⭐️ NEW HELPER WIDGET ⭐️
  // Handles long text (like hours) nicely without breaking layout
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Icon stays at the top!
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.4, // Good line height for multi-line hours
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPoiSheet({
    required String name,
    required String description,
    required Map<String, dynamic> data,
  }) {
    _saveToRecentlyViewed(data);
    final String poiId = data['id']; // Get the POI ID

    // ⭐️ NEW: Set the highlight and rebuild markers to show it ⭐️
    setState(() {
      _highlightedPoiId = poiId;
    });
    _rebuildMarkers();

    // --- 1. IMAGE LOGIC ---
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

    // --- 2. DATA EXTRACTION ---
    // final poiType = data['type'] as String?; // Unused variable removed
    final String poiType = data['type'] ?? ''; // ⭐️ Get the type safely
    final String? openingHours = data['openingHours'] as String?;
    final String? contactNumber = data['contactNumber'] as String?;
    final String? status = data['status'] as String?;
    final bool? guideRequired = data['guideRequired'] as bool?;

    // ⭐️ NEW: DEFINE VISIBILITY FLAGS ⭐️
    final bool isTouristSpot = poiType == 'Tourist Spots';
    final bool showContactInfo = poiType == 'Food & Dining' ||
        poiType == 'Business Establishments' ||
        poiType == 'Accommodations' ||
        poiType == 'Services' ||
        poiType == 'Agencies and Offices';

    // ⭐️ UPDATED LOGIC: Read directly from the new 'specificType' field ⭐️
    String? specificType = data['specificType'] as String?;

    // Safety Fallback: If the field is missing (script hasn't run on this doc yet),
    // we still try to extract it from the description.
    if (specificType == null && description.contains('Type:')) {
      final RegExp typeRegex = RegExp(r'Type:\s*([^.\n]+)');
      final match = typeRegex.firstMatch(description);
      if (match != null) {
        specificType = match.group(1)?.trim();
      }
    }

    // --- 3. ENTRANCE FEE LOGIC ---
    String entranceFeeText = '';
    if (data['entranceFee'] is Map) {
      final feeMap = data['entranceFee'] as Map<String, dynamic>;
      final int? adultFee = (feeMap['adult'] as num?)?.toInt();
      final int? childFee = (feeMap['child'] as num?)?.toInt();
      List<String> feeParts = [];
      if (adultFee != null) feeParts.add('Adult: ₱$adultFee');
      if (childFee != null) feeParts.add('Child: ₱$childFee');
      entranceFeeText = feeParts.join(', ');
      if (entranceFeeText.isEmpty) entranceFeeText = 'Varies';
    } else if (data['entranceFee'] is String) {
      entranceFeeText = data['entranceFee'] as String;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // Define controller outside StatefulBuilder
        final PageController pageController =
            PageController(viewportFraction: 0.88);
        int _currentPage = 0;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize:
                  0.55, // 🚀 NEW: Starts slightly more than half screen
              minChildSize: 0.4, // Keep min low so they can swipe it down
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Drag Handle ---
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

                        // --- NAME ---
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        // ⭐️ SPECIFIC TYPE CHIP (Below Name) ⭐️
                        if (specificType != null && specificType.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                specificType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // --- CAROUSEL UI ---
                        if (displayImages.isNotEmpty)
                          Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: PageView.builder(
                                  controller: pageController,
                                  itemCount: displayImages.length,
                                  onPageChanged: (int page) {
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
                                          memCacheHeight:
                                              600, // 🚀 ADD THIS LINE
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (context, url) =>
                                              const Center(
                                                  child:
                                                      CircularProgressIndicator()),
                                          errorWidget: (context, url, error) =>
                                              const Icon(Icons.error),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
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
                                        width: _currentPage == index ? 24 : 8,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
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

                        const SizedBox(height: 12),

                        // ⭐️ SHORT CHIPS ROW ⭐️
                        // ⭐️ SHORT CHIPS ROW (Conditional) ⭐️
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            // Only show Status, Guide, Fee for Tourist Spots
                            if (isTouristSpot) ...[
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
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ⭐️ DETAILED INFO SECTION ⭐️
                        // Check if we have anything to show
                        if ((openingHours != null && openingHours.isNotEmpty) ||
                            (showContactInfo &&
                                contactNumber != null &&
                                contactNumber.isNotEmpty))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                // Opening Hours (Show for everyone)
                                if (openingHours != null &&
                                    openingHours.isNotEmpty)
                                  _buildInfoRow(Icons.access_time,
                                      "Opening Hours", openingHours),

                                // Divider (Only if both exist)
                                if ((openingHours != null &&
                                        openingHours.isNotEmpty) &&
                                    (showContactInfo &&
                                        contactNumber != null &&
                                        contactNumber.isNotEmpty))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 50),
                                    child: Divider(
                                        height: 1, color: Colors.grey.shade300),
                                  ),

                                // Contact Number (Conditional)
                                if (showContactInfo &&
                                    contactNumber != null &&
                                    contactNumber.isNotEmpty)
                                  _buildInfoRow(Icons.phone_outlined,
                                      "Contact Number", contactNumber),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        // --- DESCRIPTION ---
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

                        // ⭐️ FIX: Use the refactored Widget here ⭐️
                        PoiTipCard(poiData: data),

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
                                  if (selectedItinerary == null) return;

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
                                                  "e.g., 'My Weekend Getaway'"),
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
                                                Navigator.of(context)
                                                    .pop(nameController.text);
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

                                  if (mounted) Navigator.of(context).pop();

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
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                ),
                                icon: const Icon(Icons.directions,
                                    color: Colors.white),
                                label: const Text("Get Directions",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white)),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final lat = data['lat'] as double?;
                                  final lng = data['lng'] as double?;
                                  if (lat != null && lng != null) {
                                    await _drawRouteToPoi(
                                        lat, lng, _currentTravelMode);
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
    ).then((_) {
      _resetHighlight();
    });
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

    // Safety check: Don't try to load 'satellite' as a JSON file
    if (fileName == 'satellite') return;

    try {
      final style = await DefaultAssetBundle.of(context)
          .loadString('assets/map_styles/$fileName');
      _mapController!.setMapStyle(style);
    } catch (e) {
      print("Error loading map style: $e");
    }
  }

  // In map_homescreen.dart
  // Replace the whole function with this one.

  // In lib/screens/map_homescreen.dart

  Future<void> _saveToRecentlyViewed(Map<String, dynamic> poiData) async {
    if (_currentUser == null) return;
    await _userDataService.saveToRecentlyViewed(
      userId: _currentUser!.uid,
      poiData: poiData,
    );
  }

  Future<Map<String, dynamic>?> _showItinerarySelectorDialog() async {
    if (_currentUser == null) return null;

    final itineraries =
        await _userDataService.getUserItineraries(_currentUser!.uid);

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

  Future<bool> _showClosureWarningDialog() async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.amber.shade800, size: 64),
              const SizedBox(height: 16),
              const Text('Route Advisory',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'This route passes through a known road closure. This could be due to a landslide, event, or other hazard.\n\nAre you sure you want to continue?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              child: const Text("Proceed Anyway",
                  style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
            ElevatedButton(
              child: const Text("Cancel Route"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        );
      },
    );
    return proceed ?? false;
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
    // 🚀 OPTIMIZATION: Run heavy math in a background isolate
    final List<Map<String, dynamic>> nearbyList = await compute(
      _calculateNearbyPoisBackground,
      {
        'pois': _allPoiData,
        'location': userLocation,
      },
    );

    if (mounted) {
      setState(() {
        _nearbyPois = nearbyList;
      });
    }
  }

  // ⭐️ MODIFIED: Fetch Guide Info when Itinerary Loads ⭐️
  Future<void> _loadActiveItineraryStream({bool forceReload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final newActiveId = prefs.getString('activeItineraryId');
    final newActiveName = prefs.getString('activeItineraryName');
    final user = FirebaseAuth.instance.currentUser;

    if (!forceReload &&
        newActiveId == _activeItineraryId &&
        _activeItineraryStream != null) {
      return;
    }

    _activeItineraryStream?.listen(null).cancel();

    if (user != null && newActiveId != null) {
      if (mounted) {
        setState(() {
          _activeItineraryId = newActiveId;
          _activeItineraryName = newActiveName ?? 'My Itinerary';

          // 1. Listen for Events (Existing logic)
          _activeItineraryStream = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('itineraries')
              .doc(_activeItineraryId)
              .collection('events')
              .where('eventTime', isGreaterThanOrEqualTo: Timestamp.now())
              .orderBy('eventTime')
              .snapshots();

          _activeItineraryStream = _userDataService.getActiveItineraryStream(
            userId: user.uid,
            itineraryId: _activeItineraryId!,
          );

          // 👇 ADD THIS LINE BACK:
          _activeItineraryStream?.listen(_updateHeadsUpEvent);
        });

        final guide = await _userDataService.fetchActiveGuide(
            userId: user.uid, itineraryId: newActiveId);
        if (mounted) {
          setState(() {
            _activeTourGuide = guide;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _activeItineraryId = null;
          _activeItineraryName = null;
          _activeItineraryStream = null;
          _activeHeadsUpEvent = null;
          _activeTourGuide = null; // Clear guide
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
    await _userDataService.clearActiveItinerary();
    _loadActiveItineraryStream(); // Refresh state
  }

  Future<void> _showEnableLocationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const EnableLocationDialog(),
    );
  }

  Future<void> _checkLocationOnStartup() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      // Only show the dialog if services are off
      await _showEnableLocationDialog();
    }
    // We don't check permissions here, _goToMyLocation() will
    // handle the system permission pop-up if needed.
  }

  Future<void> _checkInitialLocationService() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) {
      setState(() {
        _isLocationServiceEnabled = enabled;
      });
    }
  }

  // 🚀 NEW HELPER: Centers the camera with an offset to show the pin ABOVE the sheet
  Future<void> _focusOnPoi(double lat, double lng) async {
    if (_mapController == null) return;

    // 1. Define Offset
    // We increase this from 0.0012 to 0.0025 to push the camera lower,
    // effectively moving the pin HIGHER up the screen.
    const double latOffset = 0.0025;

    // 2. Animate
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(lat - latOffset, lng),
        16.5, // Nice close zoom level
      ),
    );
  }

// ⭐️ ADD THIS NEW HELPER FUNCTION ⭐️
  void _updateHeadsUpEvent(QuerySnapshot snapshot) {
    if (!mounted) return;

    // --- START OF MODIFICATION ---
    // 1. Check if the query for ALL upcoming events returned empty.
    if (snapshot.docs.isEmpty) {
      // 2. This means the itinerary is officially "finished".
      print("No upcoming events found. Clearing active itinerary.");
      // 3. Call the existing function to clear the ID from SharedPreferences.
      _clearActiveItinerary();
      return; // Stop processing.
    }
    // --- END OF MODIFICATION ---

    final now = DateTime.now();
    DocumentSnapshot? eventForToday;

    // This logic now only runs if we are sure there are upcoming events.
    for (final doc in snapshot.docs) {
      final eventTime = (doc['eventTime'] as Timestamp).toDate();
      if (_isSameDay(eventTime, now)) {
        eventForToday = doc;
        break; // Found the first one for today
      }
    }

    // Update the state
    // (This will be null if there are upcoming events, but just not for today)
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
        distanceFilter: 10, // 🚀 CHANGED to 10 meters
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
    showDialog(
      context: context,
      builder: (context) {
        return ClosureAlertDialog(closureData: closureData);
      },
    );
  }

  void _recenterLiveNavigation() {
    if (_lastKnownPosition == null) return;

    setState(() {
      _isFollowingUser = true;
    });

    _isAnimatingCamera = true;
    _mapController
        ?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _lastKnownPosition!,
          zoom: 17.5,
          tilt:
              50.0, // ⭐️ You currently have 50.0 here, which is good for driving!
          bearing: _lastKnownBearing,
        ),
      ),
    )
        .then((_) {
      _isAnimatingCamera = false;
    });
  }

  void _showGuideSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Your Guide",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tourGuides')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final guides = snapshot.data!.docs
                        .map((d) => TourGuide.fromFirestore(d))
                        .toList();

                    return ListView.builder(
                      itemCount: guides.length,
                      itemBuilder: (context, index) {
                        final guide = guides[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: guide.imageUrl.isNotEmpty
                                ? NetworkImage(guide.imageUrl)
                                : null,
                            child: guide.imageUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(guide.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(guide.org),
                          onTap: () async {
                            // 1. Save selection to Itinerary
                            if (_currentUser != null &&
                                _activeItineraryId != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_currentUser!.uid)
                                  .collection('itineraries')
                                  .doc(_activeItineraryId)
                                  .update({'guideId': guide.id});

                              // 2. Update local state
                              setState(() {
                                _activeTourGuide = guide;
                              });
                            }
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // === UI ===
  @override
  Widget build(BuildContext context) {
    final double paddingTop = MediaQuery.of(context).padding.top;

    // Calculate where the Compass should be.
    // It needs to move down if we add more cards.
    double compassTop = paddingTop + 70; // Default
    if (_activeHeadsUpEvent != null) compassTop += 90; // Push down for Heads Up
    if (_activeHeadsUpEvent != null)
      compassTop += 90; // Push down for Guide Card (approx)

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraMoveStarted: _onCameraMoveStarted,

            // Update the current zoom level as the user moves the map
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;

              // ⭐️ Check if target is outside Sagada
              bool isOutside = !_sagadaBounds.contains(position.target);
              if (isOutside != _showRecenterButton) {
                setState(() {
                  _showRecenterButton = isOutside;
                });
              }
            },

            // When the user stops moving the map, rebuild the markers
            // (This triggers your smart filtering logic)
            onCameraIdle: () {
              _rebuildMarkers();
            },

            // ⭐️ NEW: Limit the camera to the Philippines ⭐️
            cameraTargetBounds: CameraTargetBounds(
              LatLngBounds(
                // Southwest corner (Sulu/Tawi-Tawi area)
                southwest: const LatLng(4.2, 116.8),
                // Northeast corner (Batanes area)
                northeast: const LatLng(21.5, 127.0),
              ),
            ),

            // ⭐️ NEW: Prevent zooming out too far ⭐️
            // Min 5: Shows the whole country. Max 20: Street level.
            minMaxZoomPreference: const MinMaxZoomPreference(5, 20),

            initialCameraPosition: const CameraPosition(
              target: _initialPosition, // Sagada
              zoom: 14,
              tilt: 45.0, // ⭐️ ADD THIS LINE (0.0 is flat, 90.0 is horizon)
            ),

            markers: _markers,
            polylines: _polylines.union(_closureLines),
            // ⭐️ UPDATE THIS LINE ⭐️
            polygons: const {}, // Or remove the line entirely, as it will default to {}

            // UI Settings
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false, // You have your custom button
            zoomControlsEnabled: false, // Clean UI
            compassEnabled: false, // You have your custom compass widget
            mapToolbarEnabled: false, // Disable Google's "Open in Maps" buttons
            // ⭐️ RENDER THE CURRENT MAP TYPE ⭐️
            mapType: _currentMapType,
          ),
          // 1. Heads Up Card (Existing)
          // 1. Heads Up Card (Refactored)
          if (_activeHeadsUpEvent != null &&
              !_isNavigating &&
              !_isItineraryRouteVisible)
            HeadsUpCard(
              // Pass the data map, not the snapshot
              eventData: _activeHeadsUpEvent!.data() as Map<String, dynamic>,
              itineraryName: _activeItineraryName ?? 'Your Trip',
              onClear: _showClearActiveTripDialog,
              onTap: () {
                if (_activeItineraryId != null &&
                    _activeItineraryName != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ItineraryDetailScreen(
                        itineraryId: _activeItineraryId!,
                        itineraryName: _activeItineraryName!,
                      ),
                    ),
                  );
                }
              },
            ),

          // 2. Guide Card (Refactored)
          if (_activeHeadsUpEvent != null &&
              !_isNavigating &&
              !_isItineraryRouteVisible)
            GuideCard(
              guide: _activeTourGuide,
              onAssignGuide: _showGuideSelector,
              // ⭐️ Pass the logic to remove the guide ⭐️
              onRemoveGuide: () async {
                if (_currentUser != null && _activeItineraryId != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .collection('itineraries')
                      .doc(_activeItineraryId)
                      .update({
                    'guideId': FieldValue.delete()
                  }); // Deletes the field

                  setState(() {
                    _activeTourGuide = null;
                  });
                }
              },
            ),

          // 3. Compass (Updated Position)
          AnimatedPositioned(
            top: (_isNavigating && _currentInstruction.isNotEmpty)
                ? (paddingTop + 120)
                : compassTop, // Use calculated top
            right: 12,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: const RepaintBoundary(
              child: CompassWidget(),
            ),
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
                            onPressed: () async {
                              // 1. Make it async
                              // 2. Await the result
                              final result = await showModalBottomSheet(
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

                              // 3. --- ADD THIS BLOCK ---
                              // After the profile menu closes, reload the map style
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final styleName =
                                  prefs.getString('mapStyle') ?? 'tourism.json';
                              _setMapStyle(styleName);
                              // --- END OF ADDITION ---

                              // 4. (This is your existing logic for POI clicks)
                              if (result is Map<String, dynamic>) {
                                if (result['action'] == 'filter') {
                                  // Change the filter immediately
                                  _onFilterChanged(result['filterType']);
                                } else {
                                  // Existing POI logic
                                  _showPoiSheet(
                                    name: result['name'] ?? 'Unnamed',
                                    description: result['description'] ?? '',
                                    data: result,
                                  );
                                }
                              }
                            },
                          ),
                          // Dropdown filter
                          Expanded(
                            child: Container(
                              key: _filterKey, // ⭐️ ASSIGN KEY HERE ⭐️
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
                          Container(
                            key: _searchKey, // ⭐️ Assign the key here
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
                              child: IconButton(
                                icon: const Icon(Icons.search,
                                    color: Colors.black87),
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
                                      await _focusOnPoi(
                                          lat, lng); // 👈 Use Helper

                                      if (mounted) {
                                        // Small delay to let animation start
                                        Future.delayed(
                                            const Duration(milliseconds: 300),
                                            () {
                                          _showPoiSheet(
                                            name: result['name'] ?? 'Unnamed',
                                            description:
                                                result['description'] ?? '',
                                            data: result,
                                          );
                                        });
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
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
                                key:
                                    _transportKey, // ⭐️ ASSIGN KEY HERE (Replace ValueKey if present) ⭐️
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
                      // ⭐️ NEW: Map Type Switch Button (Google Style) ⭐️
                      FloatingActionButton.small(
                        heroTag: 'map_type_button',
                        onPressed: _showMapTypeSelector, // Calls the sheet
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.layers_outlined,
                            color: Colors.black87),
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

                        // --- START OF MODIFICATION ---
                        // 1. Removed the _buildMapStyleButton() call
                        child: _currentTransportRouteData == null
                            ? const SizedBox
                                .shrink() // Was _buildMapStyleButton()
                            : const SizedBox.shrink(),
                        // --- END OF MODIFICATION ---
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
                  onPoiSelected: (poiData) async {
                    final lat = poiData['lat'] as double?;
                    final lng = poiData['lng'] as double?;

                    if (lat != null && lng != null) {
                      await _focusOnPoi(lat, lng); // 👈 Use Helper
                    }

                    if (mounted) {
                      _showPoiSheet(
                        name: poiData['name'] ?? '',
                        description: poiData['description'] ?? '',
                        data: poiData,
                      );
                    }
                  },
                ),
              ),
          ],

          // Transport Details Card (Refactored)
          if (_currentTransportRouteData != null && !_isNavigating)
            TransportDetailsCard(
              transportData: _currentTransportRouteData,
              onClose: _endNavigation,
            ),

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
                // REPLACE THIS LINE:
                // ? _buildLiveNavigationUI()

                // WITH THIS NEW WIDGET:
                ? NavigationOverlay(
                    currentInstruction: _currentInstruction,
                    isMuted: _isMuted,
                    onMuteToggle: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        if (!_isMuted) {
                          _flutterTts.speak(_currentInstruction);
                        } else {
                          _flutterTts.stop();
                        }
                      });
                    },
                    liveDuration: _liveDuration,
                    liveEta: _liveEta,
                    liveDistance: _liveDistance,
                    startAddress:
                        _navigationDetails?["startAddress"] ?? "Start",
                    endAddress:
                        _navigationDetails?["endAddress"] ?? "Destination",
                    onExitNavigation: _exitLiveNavigation,
                  )
                // Keep the old panel for when NOT navigating
                : NavigationPanel(
                    state: _panelState,
                    navigationDetails: _navigationDetails,
                    liveDistance: _liveDistance,
                    liveDuration: _liveDuration,
                    isRouteLoading: _isRouteLoading,
                    currentTravelMode: _currentTravelMode,
                    isCustomRoutePreview: _isCustomRoutePreview,
                    // Callbacks
                    onStateChanged: (newState) {
                      setState(() {
                        _panelState = newState;
                      });
                    },
                    onModeChanged: (newMode) {
                      _updateRoute(newMode);
                    },
                    onCancel: _endNavigation,
                    onStartNavigation: _enterLiveNavigation,
                  ),
          ),
          if (_isOffline)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Text(
                  "Offline Mode - No Internet Connection",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // ⭐️ 2. Return to Sagada Button (Updated)
          if (_showRecenterButton && !_isNavigating)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // ⭐️ FIX: Use newLatLngZoom to reset zoom level too
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_initialPosition, 14.0),
                    );
                  },
                  icon: const Icon(Icons.wrong_location_outlined,
                      color: Colors.white),
                  label: const Text("Return to Sagada"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
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
      case 'Food & Dining': // ⭐️ ADD THIS
        iconData = Icons.restaurant_menu; // Nice knife & fork icon
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

  // Add this new helper widget to your _MapScreenState

  // ADD THIS WIDGET INSIDE YOUR _MapScreenState
  Widget _buildLocationButton() {
    IconData icon;
    Color iconColor = Colors.grey.shade700;
    Color backgroundColor = Colors.white;

    // ⭐️ NEW: Handle Disabled State First
    if (!_isLocationServiceEnabled) {
      return FloatingActionButton(
        heroTag: 'location_button',
        onPressed: () {
          // If disabled, clicking opens settings
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enable Location Services.")),
          );
          AppSettings.openAppSettings(type: AppSettingsType.location);
        },
        backgroundColor: Colors.red.shade50, // Subtle red warning tint
        child: const Icon(Icons.location_disabled, color: Colors.red),
      );
    }

    // Existing State Logic (only runs if enabled)
    switch (_locationButtonState) {
      case LocationButtonState.centered:
        icon = Icons.my_location;
        iconColor = Colors.white;
        backgroundColor = Colors.blue;
        break;
      case LocationButtonState.compass:
        icon = Icons.explore;
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
        child: RepaintBoundary(
          // 🚀 ADD THIS WRAPPER
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
        ));
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _closureSub;

  void _listenToClosures() {
    _closureSub?.cancel();
    _closureSub = FirebaseFirestore.instance
        .collection('roadClosures')
        .snapshots()
        .listen((snapshot) {
      Set<Polyline> newLines = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        List<LatLng> points = [];

        // ⭐️ 1. CHECK FOR SMOOTH POLYLINE (Priority) ⭐️
        final String? encodedPolyline = data['polyline'] as String?;
        if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
          // Decode the Google Maps string into coordinates
          final List<PointLatLng> decoded =
              PolylinePoints.decodePolyline(encodedPolyline);
          points = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
        }

        // ⭐️ 2. FALLBACK TO MANUAL POINTS (If no polyline) ⭐️
        else {
          final List<dynamic> areaPoints = data['area'] ?? [];
          points = areaPoints.map((point) {
            if (point is GeoPoint) {
              return LatLng(point.latitude, point.longitude);
            } else if (point is Map) {
              return LatLng(
                  point['latitude'] ?? 0.0, point['longitude'] ?? 0.0);
            }
            return const LatLng(0, 0);
          }).toList();
        }

        // ⭐️ 3. DRAW THE LINE ⭐️
        if (points.isNotEmpty) {
          newLines.add(
            Polyline(
              polylineId: PolylineId(doc.id),
              points: points,
              // ⭐️ STYLE UPDATE: "Caution Tape" Look
              color: Colors.redAccent.shade700
                  .withOpacity(0.8), // Slightly see-through
              width: 6, // Thick enough to be a warning
              jointType: JointType.mitered,
              // Longer dashes look more like barriers
              patterns: [PatternItem.dash(30), PatternItem.gap(20)],
              consumeTapEvents: true,
              onTap: () {
                _showClosureDetails(data);
              },
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _closureLines = newLines;
        });
      }
    }, onError: (error) {
      print("❌ ERROR in closure listener: $error");
    });
  }

  void _resetHighlight() {
    if (_highlightedPoiId != null) {
      setState(() {
        _highlightedPoiId = null;
      });
      // Call rebuild to remove the highlight marker and draw the normal set
      _rebuildMarkers();
    }
  }

  // ⭐️ Helper to check initial and stream connectivity
  void _checkConnectivity() {
    // ⭐️ FIX: Assign the listener to the variable
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      bool isNowOffline = results.contains(ConnectivityResult.none);

      if (_wasOffline && !isNowOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Internet Connection Restored"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _isOffline = isNowOffline;
          _wasOffline = isNowOffline;
        });
      }
    });
  }

  void _showFeatureDiscovery() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('tutorial_shown') == true) return; // Show only once

    List<TargetFocus> targets = [];

    // Target 1: Search
    targets.add(
      TargetFocus(
        identify: "Search",
        keyTarget: _searchKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Search Places",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20.0)),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Find tourist spots, hotels, and dining easily.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // ... Add similar targets for _filterKey and _transportKey ...

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        prefs.setBool('tutorial_shown', true);
      },
    ).show(context: context);
  }

  void _showMapTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Floating look
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Map Type",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Option 1: Default
                  _buildMapTypeOption(
                    title: "Default",
                    icon: Icons.map_outlined,
                    isSelected: _currentMapType == MapType.normal,
                    onTap: () {
                      setState(() => _currentMapType = MapType.normal);
                      Navigator.pop(context);
                    },
                  ),
                  // Option 2: Satellite
                  _buildMapTypeOption(
                    title: "Satellite",
                    icon: Icons.satellite_alt, // Requires Material Icons
                    isSelected: _currentMapType == MapType.satellite,
                    onTap: () {
                      setState(() => _currentMapType = MapType.satellite);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper for the option cards
  Widget _buildMapTypeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
              color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
            ),
            child: Icon(
              icon,
              size: 30,
              color: isSelected ? Colors.blue : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
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
}

// 🚀 Add this OUTSIDE of your _MapScreenState class
List<Map<String, dynamic>> _calculateNearbyPoisBackground(
    Map<String, dynamic> params) {
  final List<Map<String, dynamic>> allPois = params['pois'];
  final LatLng userLocation = params['location'];
  final List<Map<String, dynamic>> nearbyList = [];

  for (final poi in allPois) {
    final lat = poi['lat'] as double?;
    final lng = poi['lng'] as double?;

    if (lat != null && lng != null) {
      final double distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        lat,
        lng,
      );

      if (distance <= 2000) {
        final newPoiData = Map<String, dynamic>.from(poi);
        newPoiData['distance'] = distance;
        nearbyList.add(newPoiData);
      }
    }
  }

  nearbyList.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
  return nearbyList;
}
