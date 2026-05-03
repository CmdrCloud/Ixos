import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dj_provider.dart';
import '../providers/mood_provider.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _apiService.searchSongs(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final authProvider = context.read<AuthProvider>();
    final baseUrl = authProvider.isAuthenticated ? 'https://musicapi.sisganadero.online' : null;

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: moodProvider.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
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
                      onTap: () async {
                        // Fetch full song details because search result is missing filePath
                        final fullSong = await _apiService.getSongById(song.id);
                        if (fullSong != null && mounted) {
                          playerProvider.playSong(fullSong, baseUrl: baseUrl);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error loading song details')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSongOptions(BuildContext context, Song song) async {
    final playerProvider = context.read<PlayerProvider>();
    final djProvider = context.read<DjProvider>();
    final downloadService = context.read<DownloadService>();
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
                onTap: isDownloading
                    ? null
                    : () async {
                        if (isDownloaded) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF18181B),
                              title: const Text('Remove Download'),
                              content: Text('Remove ${song.title} from downloads?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ds.deleteDownload(song.id);
                            if (context.mounted) Navigator.pop(context);
                          }
                        } else {
                          // Search results might lack full details, fetch full song first
                          final fullSong = await _apiService.getSongById(song.id);
                          if (fullSong != null) {
                            ds.downloadSong(fullSong, baseUrl);
                          }
                          if (context.mounted) Navigator.pop(context);
                        }
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
                onTap: () async {
                  Navigator.pop(context);
                  final fullSong = await _apiService.getSongById(song.id);
                  if (fullSong != null) {
                    playerProvider.addToQueue(fullSong);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to queue')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers, color: Colors.white),
                title: const Text('Load to DJ Deck A', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final fullSong = await _apiService.getSongById(song.id);
                  if (fullSong != null) {
                    djProvider.loadToDeck(true, fullSong, 'https://musicapi.sisganadero.online');
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loaded to Deck A')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers, color: Colors.white),
                title: const Text('Load to DJ Deck B', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final fullSong = await _apiService.getSongById(song.id);
                  if (fullSong != null) {
                    djProvider.loadToDeck(false, fullSong, 'https://musicapi.sisganadero.online');
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loaded to Deck B')));
                  }
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
}
