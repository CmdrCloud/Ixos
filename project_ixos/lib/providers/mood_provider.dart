import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood.dart';

class MoodProvider with ChangeNotifier {
  Mood? _currentMood;
  Map<String, List<String>> _userMoodSongs = {}; // MoodID -> List of SongIDs
  
  Mood? get currentMood => _currentMood;

  MoodProvider() {
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Mood Songs
      final String? encodedMoods = prefs.getString('user_mood_songs');
      if (encodedMoods != null) {
        final Map<String, dynamic> decoded = jsonDecode(encodedMoods);
        _userMoodSongs = decoded.map((key, value) => MapEntry(key, List<String>.from(value)));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local library data: $e');
    }
  }

  Future<void> _saveMoodSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_mood_songs', jsonEncode(_userMoodSongs));
    } catch (e) {
      debugPrint('Error saving user mood songs: $e');
    }
  }

  // Mood Methods
  void addSongToMood(String moodId, String songId) {
    if (!_userMoodSongs.containsKey(moodId)) {
      _userMoodSongs[moodId] = [];
    }
    if (!_userMoodSongs[moodId]!.contains(songId)) {
      _userMoodSongs[moodId]!.add(songId);
      _saveMoodSongs();
      notifyListeners();
    }
  }

  void removeSongFromMood(String moodId, String songId) {
    if (_userMoodSongs.containsKey(moodId)) {
      _userMoodSongs[moodId]!.remove(songId);
      _saveMoodSongs();
      notifyListeners();
    }
  }

  bool isSongInMood(String moodId, String songId) {
    return _userMoodSongs[moodId]?.contains(songId) ?? false;
  }

  List<String> getUserSongsForMood(String moodId) {
    return _userMoodSongs[moodId] ?? [];
  }

  void setMood(Mood mood) {
    _currentMood = mood;
    notifyListeners();
  }

  Color get backgroundColor => const Color(0xFF09090B);
  Color get navBackground => const Color(0xFF18181B);
  Color get cardBackground => const Color(0xFF27272A);
  Color get borderColor => const Color(0xFF3F3F46);

  List<Color> get currentGradient {
    if (_currentMood != null) {
      return _currentMood!.gradient;
    }
    return [const Color(0xFF27272A), const Color(0xFF09090B)];
  }
}
