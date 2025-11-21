import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math'; // Import for shuffling
import 'poi_card.dart';

class DiscoveryPanel extends StatefulWidget {
  final Function(Map<String, dynamic>) onPoiSelected;
  final List<Map<String, dynamic>> nearbyPois;

  const DiscoveryPanel({
    super.key,
    required this.onPoiSelected,
    required this.nearbyPois,
  });

  @override
  State<DiscoveryPanel> createState() => _DiscoveryPanelState();
}

class _DiscoveryPanelState extends State<DiscoveryPanel> {
  bool _isExpanded = false;

  List<Map<String, dynamic>> _dynamicPois = [];
  bool _isLoadingDynamic = true;
  bool _hasFetchedDynamic = false;
  String _dynamicTitle = "Discover"; // Default title
  IconData _dynamicIcon = Icons.explore;

  @override
  void initState() {
    super.initState();
    _determineTimeContext(); // Set the title/icon immediately
  }

  // 1. Determine Time of Day Context
  void _determineTimeContext() {
    final hour = DateTime.now().hour;

    setState(() {
      if (hour >= 5 && hour < 11) {
        // Morning: 5 AM - 11 AM
        _dynamicTitle = "Good Morning! ☕";
        _dynamicIcon = Icons.wb_sunny_outlined;
      } else if (hour >= 11 && hour < 17) {
        // Day: 11 AM - 5 PM
        _dynamicTitle = "Adventure Time ⛰️";
        _dynamicIcon = Icons.hiking;
      } else {
        // Evening: 5 PM onwards
        _dynamicTitle = "Dinner & Chill 🌙";
        _dynamicIcon = Icons.nightlife;
      }
    });
  }

  void _fetchDataIfNeeded() {
    if (!_hasFetchedDynamic) {
      _fetchDynamicPois();
      _hasFetchedDynamic = true;
    }
  }

  // 2. Fetch Data based on Context
  Future<void> _fetchDynamicPois() async {
    try {
      final hour = DateTime.now().hour;
      Query query = FirebaseFirestore.instance.collection('POIs');

      // Apply filters based on time
      if (hour >= 5 && hour < 11) {
        // Morning: Show Food (Breakfast/Coffee)
        query = query.where('type', isEqualTo: 'Food & Dining');
      } else if (hour >= 11 && hour < 17) {
        // Day: Show Tourist Spots
        query = query.where('type', isEqualTo: 'Tourist Spots');
      } else {
        // Evening: Show Food (Dinner)
        query = query.where('type', isEqualTo: 'Food & Dining');
      }

      // Limit to 20 so we have enough to shuffle, but don't download everything
      final snapshot = await query.limit(30).get();

      final pois = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Safe Coordinate Parsing (reused from your logic)
        dynamic coordsData = data['coordinates'];
        double? lat, lng;
        if (coordsData is GeoPoint) {
          lat = coordsData.latitude;
          lng = coordsData.longitude;
        } else if (coordsData is Map) {
          lat = coordsData['latitude'];
          lng = coordsData['longitude'];
        }

        return {
          'id': doc.id,
          ...data,
          'lat': lat,
          'lng': lng,
        };
      }).toList();

      // 3. Shuffle to make it interesting every time
      pois.shuffle(Random());

      if (mounted) {
        setState(() {
          _dynamicPois = pois; // Display the shuffled list
          _isLoadingDynamic = false;
        });
      }
    } catch (e) {
      print("Error fetching dynamic POIs: $e");
      if (mounted) setState(() => _isLoadingDynamic = false);
    }
  }

  Widget _buildPoiCarousel(List<Map<String, dynamic>> pois, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pois.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "No suggestions right now.\nTry browsing the map!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      itemCount: pois.length,
      itemBuilder: (context, index) {
        final poi = pois[index];
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: PoiCard(poiData: poi, onTap: () => widget.onPoiSelected(poi)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isExpanded ? 300 : 70, // Slightly taller for better tabs
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRect(
        child: Column(
          children: [
            // The Pull Tab
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
                if (_isExpanded) {
                  _fetchDataIfNeeded();
                }
              },
              child: Container(
                height: 70,
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Dynamic Title
                    Row(
                      children: [
                        Icon(_dynamicIcon, color: themeColor),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discover Sagada',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _dynamicTitle, // "Good Morning", etc.
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Right: Arrow
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: themeColor,
                    ),
                  ],
                ),
              ),
            ),

            // The Content Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 50) {
                    return const SizedBox.shrink();
                  }

                  return AnimatedOpacity(
                    opacity: _isExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          // Custom Tab Bar styling
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              labelColor: themeColor,
                              unselectedLabelColor: Colors.grey,
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicator: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                              tabs: const [
                                Tab(text: "Suggestions"),
                                Tab(text: "Nearby"),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Tab 1: Time-Based Dynamic List
                                _buildPoiCarousel(
                                  _dynamicPois,
                                  _isLoadingDynamic,
                                ),

                                // Tab 2: Nearby List (Passed from Parent)
                                _buildPoiCarousel(
                                  widget.nearbyPois,
                                  false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
