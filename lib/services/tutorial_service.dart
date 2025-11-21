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
}
