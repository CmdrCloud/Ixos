import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dj_provider.dart';
import '../providers/mood_provider.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';

class PlaylistView extends StatefulWidget {
  final Mood mood;

  const PlaylistView({super.key, required this.mood});

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  final ApiService _apiService = ApiService();
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final moodProvider = context.read<MoodProvider>();
    final userSongIds = moodProvider.getUserSongsForMood(widget.mood.id);

    final allSongs = await _apiService.getSongsByMood(''); // Passing empty to get all
    
    if (mounted) {
      setState(() {
        _songs = allSongs.where((s) => userSongIds.contains(s.id)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.read<PlayerProvider>();
    final authProvider = context.read<AuthProvider>();
    final baseUrl = authProvider.isAuthenticated ? 'https://musicapi.sisganadero.online' : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.mood.displayName),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.mood.gradient.first,
                      const Color(0xFF09090B),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _parseIconName(widget.mood.iconName),
                    size: 80,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_songs.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No songs found for this mood.', style: TextStyle(color: Colors.white54))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white54),
                    ),
                    title: Text(song.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(song.artistName ?? 'Unknown Artist',
                        style: TextStyle(color: Colors.white.withOpacity(0.6))),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      onPressed: () => _showSongOptions(context, song),
                    ),
                    onTap: () {
                      playerProvider.setQueue(_songs, initialIndex: index, baseUrl: baseUrl);
                    },
                  );
                },
                childCount: _songs.length,
              ),
            ),
        ],
      ),
    );
  }

  void _showSongOptions(BuildContext context, Song song) {
    final playerProvider = context.read<PlayerProvider>();
    final moodProvider = context.read<MoodProvider>();
    final downloadService = context.read<DownloadService>();
    final authProvider = context.read<AuthProvider>();
    final baseUrl = 'https://musicapi.sisganadero.online';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Consumer<DownloadService>(
        builder: (context, ds, _) {
          final isDownloaded = ds.isDownloaded(song.id);
          final isDownloading = ds.isDownloading(song.id);
          final progress = ds.getProgress(song.id);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: isDownloading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isDownloaded ? Icons.download_done : Icons.download,
                        color: isDownloaded ? Colors.greenAccent : Colors.white,
                      ),
                title: Text(
                  isDownloading
                      ? 'Downloading... ${(progress * 100).toInt()}%'
                      : isDownloaded
                          ? 'Downloaded'
                          : 'Download Song',
                  style: TextStyle(color: isDownloaded ? Colors.greenAccent : Colors.white),
                ),
                onTap: isDownloaded || isDownloading
                    ? null
                    : () {
                        ds.downloadSong(song, baseUrl);
                        Navigator.pop(context);
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
              ListTile(
                leading: const Icon(Icons.playlist_remove, color: Colors.redAccent),
                title: const Text('Remove from this Mood', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  moodProvider.removeSongFromMood(widget.mood.id, song.id);
                  Navigator.pop(context);
                  _loadSongs(); // Refresh the list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Removed from mood')),
                  );
                },
              ),
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
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  void _showMoodSelection(BuildContext outerContext, Song song) async {
    final moods = await _apiService.getMoods();
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

  IconData _parseIconName(String iconName) {
    switch (iconName) {
      case 'sentiment_satisfied': return Icons.sentiment_satisfied;
      case 'cloud': return Icons.cloud;
      case 'headphones': return Icons.headphones;
      case 'bolt': return Icons.bolt;
      case 'spa': return Icons.spa;
      case 'local_bar': return Icons.local_bar;
      case 'nightlight': return Icons.nightlight;
      case 'favorite': return Icons.favorite;
      default: return Icons.music_note;
    }
  }
}
