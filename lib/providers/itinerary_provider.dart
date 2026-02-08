import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItineraryProvider with ChangeNotifier {
  String? _activeItineraryId;
  String? _activeItineraryName;

  String? get activeItineraryId => _activeItineraryId;
  String? get activeItineraryName => _activeItineraryName;

  // Load saved ID from storage when app starts
  Future<void> loadActiveItinerary() async {
    final prefs = await SharedPreferences.getInstance();
    _activeItineraryId = prefs.getString('activeItineraryId');
    _activeItineraryName = prefs.getString('activeItineraryName');
    notifyListeners();
  }

  // Set new active trip
  Future<void> setActiveItinerary(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeItineraryId', id);
    await prefs.setString('activeItineraryName', name);

    _activeItineraryId = id;
    _activeItineraryName = name;
    notifyListeners(); // ⭐️ Triggers UI updates in Map & List screens
  }

  // Clear active trip
  Future<void> clearActiveItinerary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeItineraryId');
    await prefs.remove('activeItineraryName');

    _activeItineraryId = null;
    _activeItineraryName = null;
    notifyListeners();
  }
}
