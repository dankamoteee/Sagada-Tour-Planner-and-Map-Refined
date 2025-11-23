import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static void showTutorial({
    required BuildContext context,
    required GlobalKey searchKey, // 👈 Added this parameter
    required GlobalKey filterKey,
    required GlobalKey transportKey,
  }) async {
    // 1. Check if the user has already seen the tutorial
    final prefs = await SharedPreferences.getInstance();
    final bool isSeen = prefs.getBool('feature_tutorial_seen') ?? false;

    if (isSeen) return; // Stop if already seen

    // 2. Define the Targets
    List<TargetFocus> targets = [];

    // Target 1: Search Button
    targets.add(
      TargetFocus(
        identify: "search_key",
        keyTarget: searchKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Search Places",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to search for specific tourist spots, hotels, or restaurants.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
    );

    // Target 2: Filter Dropdown
    targets.add(
      TargetFocus(
        identify: "filter_key",
        keyTarget: filterKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Filter Categories",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Use this dropdown to show only specific types of places, like 'Food & Dining' or 'Accommodations'.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 15,
      ),
    );

    // Target 3: Transport Button
    targets.add(
      TargetFocus(
        identify: "transport_key",
        keyTarget: transportKey,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Transport Routes",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap the bus icon to view Jeepney and Bus schedules, fares, and routes.",
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
    );

    // 3. Show the Tutorial
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        prefs.setBool('feature_tutorial_seen', true);
      },
      onSkip: () {
        prefs.setBool('feature_tutorial_seen', true);
        return true;
      },
    ).show(context: context);
  }

  // 🆕 ADD THIS METHOD
  static void showEventEditorTutorial({
    required BuildContext context,
    required GlobalKey timeKey,
    required GlobalKey locationKey,
    required GlobalKey saveKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Check a unique key for this specific screen
    if (prefs.getBool('event_editor_tutorial_seen') ?? false) return;

    List<TargetFocus> targets = [];

    // Target 1: Date & Time
    targets.add(
      TargetFocus(
        identify: "time_key",
        keyTarget: timeKey,
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Set Date & Time",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to choose when this activity starts.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    // Target 2: Destination
    targets.add(
      TargetFocus(
        identify: "location_key",
        keyTarget: locationKey,
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pick a Location",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Search for a tourist spot, restaurant, or hotel to add to your plan.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    // Target 3: Save Button
    targets.add(
      TargetFocus(
        identify: "save_key",
        keyTarget: saveKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Save Event",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Once you're done, tap here to finalize and add it to your itinerary.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () => prefs.setBool('event_editor_tutorial_seen', true),
      onSkip: () {
        prefs.setBool('event_editor_tutorial_seen', true);
        return true;
      },
    ).show(context: context);
  }

  // 🆕 ADD THIS METHOD for Itinerary List
  static void showListTutorial({
    required BuildContext context,
    required GlobalKey createKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('list_tutorial_seen') ?? false) return;

    List<TargetFocus> targets = [];

    // Target: Create New Button
    targets.add(
      TargetFocus(
        identify: "create_key",
        keyTarget: createKey,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Start Planning",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to create a new itinerary for your Sagada adventure.",
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
    );

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () => prefs.setBool('list_tutorial_seen', true),
      onSkip: () {
        prefs.setBool('list_tutorial_seen', true);
        return true;
      },
    ).show(context: context);
  }

  // 🆕 ADD THIS METHOD for Itinerary Details
  static void showDetailTutorial({
    required BuildContext context,
    required GlobalKey mapKey,
    required GlobalKey addKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('detail_tutorial_seen') ?? false) return;

    List<TargetFocus> targets = [];

    // Target 1: Show on Map (Day 1)
    targets.add(
      TargetFocus(
        identify: "map_key",
        keyTarget: mapKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.end, // Align text to right
                children: [
                  Text(
                    "Visualize Route",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap 'Show on Map' to see the route for this specific day and start navigation.",
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 8,
      ),
    );

    // Target 2: Add Event FAB
    targets.add(
      TargetFocus(
        identify: "add_key",
        keyTarget: addKey,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Add Activities",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to add more destinations or custom events to your plan.",
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
    );

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () => prefs.setBool('detail_tutorial_seen', true),
      onSkip: () {
        prefs.setBool('detail_tutorial_seen', true);
        return true;
      },
    ).show(context: context);
  }
}
