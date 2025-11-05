import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'poi_card.dart';

class DiscoveryPanel extends StatefulWidget {
  final Function(Map<String, dynamic>) onPoiSelected;
  final List<Map<String, dynamic>> nearbyPois; // This is correct!

  const DiscoveryPanel({
    super.key,
    required this.onPoiSelected,
    required this.nearbyPois, // This is correct!
  });

  @override
  State<DiscoveryPanel> createState() => _DiscoveryPanelState();
}

class _DiscoveryPanelState extends State<DiscoveryPanel> {
  bool _isExpanded = false;

  // --- START OF CHANGES ---

  // We ONLY keep the state for "Popular". "Nearby" is now handled by the MapScreen.
  List<Map<String, dynamic>> _popularPois = [];
  bool _isLoadingPopular = true;
  bool _hasFetchedPopular = false; // Changed variable name for clarity

  @override
  void initState() {
    super.initState();
    // Data fetching will be triggered on first expansion
  }

  // Simplified to only fetch "Popular"
  void _fetchDataIfNeeded() {
    if (!_hasFetchedPopular) {
      _fetchPopularPois();
      _hasFetchedPopular = true;
    }
  }

  // This function for "Popular" stays the same
  Future<void> _fetchPopularPois() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('POIs')
          .where('recommended', isEqualTo: true)
          .get();

      final pois = snapshot.docs.map((doc) {
        final data = doc.data();
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
      if (mounted) {
        setState(() {
          _popularPois = pois;
          _isLoadingPopular = false;
        });
      }
    } catch (e) {
      print("Error fetching popular POIs: $e");
      if (mounted) setState(() => _isLoadingPopular = false);
    }
  }

  // 🛑 The old _fetchNearbyPois() function is COMPLETELY REMOVED.
  // 🛑 The old _nearbyPois = [] and _isLoadingNearby = true are COMPLETELY REMOVED.

  // --- END OF CHANGES ---

  Widget _buildPoiCarousel(List<Map<String, dynamic>> pois, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- START OF FIX ---
    // Use a more helpful message if the list (which is now passed in) is empty.
    if (pois.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "No places found.\nTry moving around the map to refresh.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // --- END OF FIX ---

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isExpanded ? 280 : 65,
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
            // The Pull Tab (no changes here)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
                if (_isExpanded) {
                  _fetchDataIfNeeded(); // This now only fetches "Popular"
                }
              },
              child: Container(
                height: 65,
                color: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Discover Places',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // The content area
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
                          const TabBar(
                            tabs: [
                              Tab(text: "Popular in Sagada"),
                              Tab(text: "Nearby"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // "Popular" tab uses its own internal state
                                _buildPoiCarousel(
                                  _popularPois,
                                  _isLoadingPopular,
                                ),

                                // --- ⭐️ THIS IS THE FIX ⭐️ ---
                                // "Nearby" tab now uses the list from MapScreen.
                                // It's never "loading" because MapScreen already did the work.
                                _buildPoiCarousel(
                                  widget.nearbyPois, // 👈 Use the widget's list
                                  false, // 👈 Pass 'false' for loading
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
