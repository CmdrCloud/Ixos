import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/song.dart';
import '../models/mood.dart';

class ApiService {
  final String baseUrl;
  final _storage = const FlutterSecureStorage();

  ApiService({this.baseUrl = 'https://musicapi.sisganadero.online'});

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'accessToken');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String?> _getUserId() async {
    return await _storage.read(key: 'userId');
  }

  Future<List<Mood>> getMoods() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/moods'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Mood.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching moods: $e');
    }
    
    return [
      Mood(id: '1', name: 'feliz', displayName: 'Feliz', iconName: 'sentiment_satisfied', gradientStart: '#FACC15', gradientEnd: '#F97316', sortOrder: 1),
      Mood(id: '2', name: 'triste', displayName: 'Triste', iconName: 'cloud', gradientStart: '#475569', gradientEnd: '#1E3A5F', sortOrder: 2),
      Mood(id: '3', name: 'focus', displayName: 'Focus', iconName: 'headphones', gradientStart: '#6366F1', gradientEnd: '#7C3AED', sortOrder: 3),
      Mood(id: '4', name: 'energia', displayName: 'Energía', iconName: 'bolt', gradientStart: '#DC2626', gradientEnd: '#18181B', sortOrder: 4),
      Mood(id: '5', name: 'relax', displayName: 'Relax', iconName: 'spa', gradientStart: '#2DD4BF', gradientEnd: '#059669', sortOrder: 5),
      Mood(id: '6', name: 'fiesta', displayName: 'Fiesta', iconName: 'local_bar', gradientStart: '#EC4899', gradientEnd: '#E11D48', sortOrder: 6),
      Mood(id: '7', name: 'dormir', displayName: 'Dormir', iconName: 'nightlight', gradientStart: '#1C1917', gradientEnd: '#000000', sortOrder: 7),
      Mood(id: '8', name: 'romance', displayName: 'Romance', iconName: 'favorite', gradientStart: '#FB7185', gradientEnd: '#EF4444', sortOrder: 8),
    ];
  }

  Future<List<Song>> getSongsByMood(String moodId) async {
    try {
      // Increased limit to 500 to fetch all songs at once for now
      final queryParams = moodId.isNotEmpty ? '?moodId=$moodId&limit=500' : '?limit=500';
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/songs$queryParams'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Song.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching songs by mood: $e');
    }
    return [];
  }

  Future<List<Song>> searchSongs(String query) async {
    try {
      print('DEBUG: Searching for: $query');
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/search?q=$query'),
        headers: await _headers(),
      );

      print('DEBUG Search response status: ${response.statusCode}');
      print('DEBUG Search response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        
        List<dynamic> songList = [];
        
        if (data is Map && data.containsKey('songs')) {
          songList = data['songs'];
        } else if (data is Map && data.containsKey('data')) {
          songList = data['data'];
        } else if (data is List) {
          songList = data;
        }

        return songList.map((json) {
          if (json is Map && json.containsKey('entityType')) {
             return Song(
                id: json['entityId'] ?? '',
                fileId: json['entityId'] ?? '',
                filePath: '', 
                title: json['primaryText'] ?? 'Unknown',
                artistId: '', 
                artistName: json['secondaryText'] ?? 'Unknown Artist',
                coverUrl: json['imageUrl'],
                durationS: 0,
              );
          }
          return Song.fromJson(json);
        }).toList();
      }
    } catch (e) {
      print('DEBUG Search Exception: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getCatalog() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/catalog'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching catalog: $e');
    }
    return {};
  }

  Future<Song?> getSongById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/songs/$id'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Song.fromJson(data);
      }
    } catch (e) {
      print('Error fetching song by ID: $e');
    }
    return null;
  }
}
