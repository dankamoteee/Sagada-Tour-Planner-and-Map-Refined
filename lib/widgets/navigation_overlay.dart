import 'package:flutter/material.dart';

class NavigationOverlay extends StatelessWidget {
  final String currentInstruction;
  final bool isMuted;
  final VoidCallback onMuteToggle;
  final String liveDuration;
  final String liveEta;
  final String liveDistance;
  final String startAddress;
  final String endAddress;
  final VoidCallback onExitNavigation;

  const NavigationOverlay({
    super.key,
    required this.currentInstruction,
    required this.isMuted,
    required this.onMuteToggle,
    required this.liveDuration,
    required this.liveEta,
    required this.liveDistance,
    required this.startAddress,
    required this.endAddress,
    required this.onExitNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildTurnByTurnBanner(context),
        _buildNavigationInfoBar(context),
      ],
    );
  }

  Widget _buildTurnByTurnBanner(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12.0,
      left: 12.0,
      right: 12.0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: currentInstruction.isEmpty
            ? const SizedBox.shrink()
            : Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme.of(context).primaryColor,
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0, right: 8.0, top: 8.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          currentInstruction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                        ),
                        onPressed: onMuteToggle,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNavigationInfoBar(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        margin: const EdgeInsets.all(12),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Time and Distance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              liveDuration,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ETA: $liveEta',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.green),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            liveDistance,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, thickness: 1),

                    // Row 2: Start Address
                    Row(
                      children: [
                        Icon(Icons.trip_origin,
                            color: Colors.grey.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            startAddress,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Row 3: End Address
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Theme.of(context).primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            endAddress,
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
              const SizedBox(width: 8),
              // Exit Button
              ElevatedButton(
                onPressed: onExitNavigation,
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
}
