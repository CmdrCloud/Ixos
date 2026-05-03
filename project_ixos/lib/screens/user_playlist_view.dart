import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/mood_provider.dart';

class UserPlaylistView extends StatefulWidget {
  final Playlist playlist;
  final bool isLikedSongs;

  const UserPlaylistView({
    super.key,
    required this.playlist,
    this.isLikedSongs = false,
  });

  @override
  State<UserPlaylistView> createState() => _UserPlaylistViewState();
}

class _UserPlaylistViewState extends State<UserPlaylistView> {
  final ApiService _apiService = ApiService();
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isLikedSongs) {
        final moodProvider = context.read<MoodProvider>();
        final likedIds = moodProvider.likedSongIds;
        final allSongs = await _apiService.getSongsByMood(''); // Get all
        setState(() {
          _songs = allSongs.where((s) => likedIds.contains(s.id)).toList();
          _isLoading = false;
        });
      } else {
        // Fallback for custom playlists (if any remain)
        final songs = await _apiService.getPlaylistSongs(widget.playlist.id);
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading songs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.read<PlayerProvider>();
    final moodProvider = context.watch<MoodProvider>();
    final authProvider = context.read<AuthProvider>();
    final baseUrl = authProvider.isAuthenticated ? 'https://musicapi.sisganadero.online' : null;

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.playlist.name),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.isLikedSongs ? Colors.redAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.5),
                      moodProvider.backgroundColor,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.isLikedSongs ? Icons.favorite : Icons.playlist_play,
                    size: 64,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_off_outlined, size: 48, color: Colors.white24),
                    const SizedBox(height: 16),
                    Text(
                      widget.isLikedSongs ? 'No liked songs yet' : 'This playlist is empty',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isLikedSongs)
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
              title: const Text('Remove from Likes', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                context.read<MoodProvider>().toggleLike(song.id);
                Navigator.pop(context);
                _loadSongs();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Liked Songs')));
              },
            ),
          if (!widget.isLikedSongs)
            ListTile(
              leading: Icon(
                context.read<MoodProvider>().isLiked(song.id) ? Icons.favorite : Icons.favorite_border,
                color: context.read<MoodProvider>().isLiked(song.id) ? Colors.redAccent : Colors.white,
              ),
              title: Text(
                context.read<MoodProvider>().isLiked(song.id) ? 'Unlike Song' : 'Like Song',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                context.read<MoodProvider>().toggleLike(song.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.read<MoodProvider>().isLiked(song.id) ? 'Added to Likes' : 'Removed from Likes'),
                  ),
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
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white),
            title: const Text('Add to Queue', style: TextStyle(color: Colors.white)),
            onTap: () {
              context.read<PlayerProvider>().addToQueue(song);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showMoodSelection(BuildContext context, Song song) async {
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
