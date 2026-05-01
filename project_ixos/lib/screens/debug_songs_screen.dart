import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/mood_provider.dart';
import '../services/api_service.dart';

class DebugSongsScreen extends StatefulWidget {
  const DebugSongsScreen({super.key});

  @override
  State<DebugSongsScreen> createState() => _DebugSongsScreenState();
}

class _DebugSongsScreenState extends State<DebugSongsScreen> {
  final ApiService _apiService = ApiService();
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllSongs();
  }

  Future<void> _loadAllSongs() async {
    try {
      // Using the base songs endpoint
      final songs = await _apiService.getSongsByMood(''); // Passing empty to get all if API supports it, or we can add a specific method
      
      // If the above doesn't work as expected, we'll try a direct fetch to /api/v1/songs
      if (songs.isEmpty) {
        final response = await _apiService.getSongsByMood('all'); // some APIs use 'all'
        setState(() {
          _songs = response;
          _isLoading = false;
        });
      } else {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.read<PlayerProvider>();
    final authProvider = context.read<AuthProvider>();
    final moodProvider = context.watch<MoodProvider>();
    
    // Explicitly using the production URL to ensure relative paths are resolved
    const baseUrl = 'https://musicapi.gamobo.shop';

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      appBar: AppBar(
        title: const Text('DEBUG: All Songs'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAllSongs();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _songs.isEmpty
                  ? const Center(child: Text('No songs found in BD'))
                  : ListView.builder(
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        return ListTile(
                          leading: const Icon(Icons.music_note, color: Colors.white54),
                          title: Text(song.title, style: const TextStyle(color: Colors.white)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${song.id}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              const SizedBox(height: 4),
                              SelectableText(
                                'Stream URL: https://musicapi.gamobo.shop/music/${song.fileId.endsWith('.mp3') ? song.fileId : '${song.fileId}.mp3'}',
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 10),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () {
                            playerProvider.playSong(song, baseUrl: baseUrl);
                          },
                        );
                      },
                    ),
    );
  }
}
