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
    const baseUrl = 'https://musicapi.sisganadero.online';

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      appBar: AppBar(
        title: Text('DEBUG: Songs (${_songs.length})'),
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
                                'Stream URL: ${song.filePath}',
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 10),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white54),
                            onPressed: () => _showSongOptions(context, song),
                          ),
                          onTap: () {
                            playerProvider.setQueue(_songs, initialIndex: index, baseUrl: baseUrl);
                          },
                        );
                      },
                    ),
    );
  }

  void _showSongOptions(BuildContext context, Song song) {
    final playerProvider = context.read<PlayerProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white),
            title: const Text('Add to Queue', style: TextStyle(color: Colors.white)),
            onTap: () {
              playerProvider.addToQueue(song);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to queue')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.white),
            title: const Text('Add to Mood', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showMoodSelection(context, song);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showMoodSelection(BuildContext outerContext, Song song) async {
    final apiService = ApiService();
    final moods = await apiService.getMoods();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select Mood', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: moods.length,
              itemBuilder: (context, index) {
                final mood = moods[index];
                return ListTile(
                  leading: Icon(Icons.mood, color: mood.gradient.first),
                  title: Text(mood.displayName, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    if (!mounted) return;
                    context.read<MoodProvider>().addSongToMood(mood.id, song.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to ${mood.displayName}')),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
