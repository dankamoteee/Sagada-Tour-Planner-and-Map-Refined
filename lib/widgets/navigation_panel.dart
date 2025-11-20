import 'package:flutter/material.dart';

// Move the Enum here so it belongs to the widget component
enum NavigationPanelState { hidden, minimized, expanded }

class NavigationPanel extends StatelessWidget {
  final NavigationPanelState state;
  final Map<String, dynamic>? navigationDetails;
  final String liveDistance;
  final String liveDuration;
  final bool isRouteLoading;
  final String currentTravelMode;
  final bool isCustomRoutePreview;

  // Callbacks
  final Function(NavigationPanelState) onStateChanged;
  final Function(String) onModeChanged;
  final VoidCallback onCancel;
  final VoidCallback onStartNavigation;

  const NavigationPanel({
    super.key,
    required this.state,
    required this.navigationDetails,
    required this.liveDistance,
    required this.liveDuration,
    required this.isRouteLoading,
    required this.currentTravelMode,
    required this.isCustomRoutePreview,
    required this.onStateChanged,
    required this.onModeChanged,
    required this.onCancel,
    required this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case NavigationPanelState.expanded:
        return _buildExpandedPanel(context);
      case NavigationPanelState.minimized:
        return _buildMinimizedPanel(context);
      case NavigationPanelState.hidden:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMinimizedPanel(BuildContext context) {
    if (navigationDetails == null) return const SizedBox.shrink();

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
            onTap: () => onStateChanged(NavigationPanelState.expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                        'ETA: $liveDuration', // Use liveDuration passed from parent
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text('Show details'),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.red,
                    onPressed: onCancel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedPanel(BuildContext context) {
    if (navigationDetails == null) return const SizedBox.shrink();

    final Color themeColor = Theme.of(context).primaryColor;

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
                  onPressed: () =>
                      onStateChanged(NavigationPanelState.minimized),
                ),
              ],
            ),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.trip_origin,
                color: Colors.grey.shade600,
              ),
              title: const Text(
                "Starting Point",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                navigationDetails!["startAddress"] ?? "Loading...",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                navigationDetails!["endAddress"] ?? "Loading address...",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            if (isRouteLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: themeColor),
                ),
              )
            else
              Row(
                children: [
                  _buildInfoChip(Icons.map, liveDistance),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.timer, liveDuration),
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
                ),
                _buildModeButton(
                  "Walking",
                  Icons.directions_walk,
                  "walking",
                ),
                _buildModeButton(
                  "Cycling",
                  Icons.directions_bike,
                  "bicycling",
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      isCustomRoutePreview ? "Clear Route" : "Cancel",
                    ),
                  ),
                ),
                if (!isCustomRoutePreview) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onStartNavigation,
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

  Widget _buildModeButton(String label, IconData icon, String mode) {
    final bool isSelected = currentTravelMode == mode;
    return Column(
      children: [
        InkWell(
          onTap: () => onModeChanged(mode),
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
}
