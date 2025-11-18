import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// A simple model to hold our POIs for the dropdown
class PoiStub {
  final String id;
  final String name;
  final GeoPoint coordinates;
  PoiStub({required this.id, required this.name, required this.coordinates});
}

class RouteGeneratorPage extends StatefulWidget {
  const RouteGeneratorPage({super.key});

  @override
  State<RouteGeneratorPage> createState() => _RouteGeneratorPageState();
}

class _RouteGeneratorPageState extends State<RouteGeneratorPage> {
  // ⭐️ --- IMPORTANT: ADD YOUR API KEY HERE --- ⭐️
  // This key must have the "Directions API" enabled in your Google Cloud console
  final String _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fareController = TextEditingController();
  final _scheduleController = TextEditingController();

  // State for the POI pickers
  bool _isLoadingPois = true;
  List<PoiStub> _allPois = [];
  PoiStub? _startPoi;
  PoiStub? _endPoi;
  final List<PoiStub> _waypoints = [];

  // State for the map preview
  GoogleMapController? _mapController;
  Set<Polyline> _previewPolylines = {};
  Set<Marker> _previewMarkers = {};

  // State for the "Generate" button
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _fetchPois();
  }

  /// Fetches all POIs from Firestore to populate the dropdowns
  Future<void> _fetchPois() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('POIs').get();
      final pois = snapshot.docs.map((doc) {
        final data = doc.data();
        return PoiStub(
          id: doc.id,
          name: data['name'] ?? 'Unnamed',
          coordinates: data['coordinates'] ?? const GeoPoint(0, 0),
        );
      }).toList();

      // Sort POIs alphabetically by name
      pois.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _allPois = pois;
        _isLoadingPois = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load POIs: $e')),
        );
      }
    }
  }

  /// The main logic function that calls the Directions API
  Future<void> _generateAndSaveRoute() async {
    if (!_formKey.currentState!.validate()) {
      return; // Form is invalid
    }
    if (_startPoi == null || _endPoi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Start and End point.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _previewPolylines.clear(); // Clear old preview
      _previewMarkers.clear();
    });

    try {
      // 1. Format coordinates for the API call
      final origin =
          '${_startPoi!.coordinates.latitude},${_startPoi!.coordinates.longitude}';
      final destination =
          '${_endPoi!.coordinates.latitude},${_endPoi!.coordinates.longitude}';

      // Format waypoints: "optimize:true|lat,lng|lat,lng|..."
      String waypointsString = '';
      if (_waypoints.isNotEmpty) {
        waypointsString = 'optimize:true|';
        waypointsString += _waypoints
            .map((poi) =>
                '${poi.coordinates.latitude},${poi.coordinates.longitude}')
            .join('|');
      }

      // 2. Call the Google Maps Directions API
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&waypoints=$waypointsString&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        // 3. Extract the encoded polyline
        final String encodedPolyline =
            data['routes'][0]['overview_polyline']['points'];

        // 4. --- (Optional) Show a preview on the admin map ---
        _showPreviewOnMap(encodedPolyline);

        // 5. Save the new route to Firestore
        await FirebaseFirestore.instance.collection('transportRoutes').add({
          'routeName': _nameController.text,
          'fareDetails': _fareController.text,
          'schedule': _scheduleController.text,
          'polyline': encodedPolyline, // ⭐️ This is the generated string
          'startPoiId': _startPoi!.id,
          'endPoiId': _endPoi!.id,
          'waypointIds': _waypoints.map((poi) => poi.id).toList(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Success! New transport route saved.'),
                backgroundColor: Colors.green),
          );
        }
        // Clear the form
        _nameController.clear();
        _fareController.clear();
        _scheduleController.clear();
        setState(() {
          _startPoi = null;
          _endPoi = null;
          _waypoints.clear();
          _previewPolylines.clear();
          _previewMarkers.clear();
        });
      } else {
        throw Exception('Directions API error: ${data['status']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate route: $e')),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  /// Decodes the polyline and displays it on the map preview
  /// Decodes the polyline and displays it on the map preview
  void _showPreviewOnMap(String encodedPolyline) {
    // --- THIS IS THE FIX ---
    final List<PointLatLng> points =
        PolylinePoints.decodePolyline(encodedPolyline);
    // --- END OF FIX ---

    final List<LatLng> latLngPoints =
        points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    if (latLngPoints.isEmpty) return;

    final Polyline routeLine = Polyline(
      polylineId: const PolylineId('preview_route'),
      color: Colors.purple,
      width: 5,
      points: latLngPoints,
    );

    final Marker startMarker = Marker(
      markerId: const MarkerId('start'),
      position: latLngPoints.first,
      infoWindow: InfoWindow(title: 'Start: ${_startPoi!.name}'),
    );
    final Marker endMarker = Marker(
      markerId: const MarkerId('end'),
      position: latLngPoints.last,
      infoWindow: InfoWindow(title: 'End: ${_endPoi!.name}'),
    );

    setState(() {
      _previewPolylines = {routeLine};
      _previewMarkers = {startMarker, endMarker};
    });

    // Animate camera to fit the route
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        _boundsFromLatLngList(latLngPoints),
        50.0, // Padding
      ),
    );
  }

  /// Helper to create LatLngBounds
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

  /// Builds a single dropdown POI picker
  Widget _buildPoiPicker(
      {required String title,
      PoiStub? selectedPoi,
      required ValueChanged<PoiStub?> onChanged}) {
    return DropdownButtonFormField<PoiStub>(
      value: selectedPoi,
      hint: Text(title),
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: _allPois.map((poi) {
        return DropdownMenuItem<PoiStub>(
          value: poi,
          child: Text(poi.name),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select a point.' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Route Admin'),
      ),
      body: _isLoadingPois
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- 1. THE FORM ---
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          labelText: 'Route Name (e.g., "Bontoc Loop")'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fareController,
                      decoration: const InputDecoration(
                          labelText: 'Fare Details (e.g., "₱150")'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _scheduleController,
                      decoration: const InputDecoration(
                          labelText: 'Schedule (e.g., "6am - 5pm, Daily")'),
                    ),
                    const SizedBox(height: 24),

                    // --- 2. THE POI PICKERS ---
                    _buildPoiPicker(
                      title: 'Select Start Point',
                      selectedPoi: _startPoi,
                      onChanged: (poi) => setState(() => _startPoi = poi),
                    ),
                    const SizedBox(height: 12),
                    _buildPoiPicker(
                      title: 'Select End Point',
                      selectedPoi: _endPoi,
                      onChanged: (poi) => setState(() => _endPoi = poi),
                    ),
                    const SizedBox(height: 24),
                    const Text('Waypoints (Optional, in order):',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),

                    // --- 3. WAYPOINT LIST ---
                    Wrap(
                      spacing: 8.0,
                      children: _waypoints.map((poi) {
                        return Chip(
                          label: Text(poi.name),
                          onDeleted: () {
                            setState(() {
                              _waypoints.remove(poi);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    DropdownButton<PoiStub>(
                      hint: const Text('Add a waypoint...'),
                      isExpanded: true,
                      items: _allPois.map((poi) {
                        return DropdownMenuItem<PoiStub>(
                          value: poi,
                          // Don't let user add a poi that's already a start/end/waypoint
                          enabled: poi.id != _startPoi?.id &&
                              poi.id != _endPoi?.id &&
                              !_waypoints.any((wp) => wp.id == poi.id),
                          child: Text(poi.name),
                        );
                      }).toList(),
                      onChanged: (poi) {
                        if (poi != null) {
                          setState(() {
                            _waypoints.add(poi);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- 4. MAP PREVIEW ---
                    SizedBox(
                      height: 300,
                      child: GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(17.0885, 120.8996), // Sagada
                          zoom: 12,
                        ),
                        onMapCreated: (controller) =>
                            _mapController = controller,
                        polylines: _previewPolylines,
                        markers: _previewMarkers,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- 5. SUBMIT BUTTON ---
                    ElevatedButton.icon(
                      icon: _isGenerating
                          ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isGenerating
                          ? 'Generating...'
                          : 'Generate & Save Route'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isGenerating ? null : _generateAndSaveRoute,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
