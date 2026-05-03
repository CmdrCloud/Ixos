import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/mood.dart';
import '../providers/mood_provider.dart';
import '../services/download_service.dart';
import 'playlist_view.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ApiService _apiService = ApiService();
  List<Mood> _moods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    try {
      final moods = await _apiService.getMoods();
      setState(() {
        _moods = moods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLibrary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Mood Collections',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._moods.map((mood) {
                    final moodSongs = moodProvider.getUserSongsForMood(mood.id);
                    final songCount = moodSongs.length;
                    
                    return Consumer<DownloadService>(
                      builder: (context, downloadService, _) {
                        final isDownloaded = downloadService.isMoodDownloaded(moodSongs);
                        final isDownloading = downloadService.isMoodDownloading(moodSongs);

                        return _LibraryTile(
                          title: mood.displayName,
                          subtitle: '$songCount songs assigned',
                          icon: Icons.mood,
                          iconColor: mood.gradient.first,
                          trailing: IconButton(
                            icon: isDownloading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(
                                    isDownloaded ? Icons.download_done : Icons.download,
                                    color: isDownloaded ? Colors.greenAccent : Colors.white38,
                                  ),
                            onPressed: isDownloading || (moodSongs.isEmpty && !isDownloaded)
                                ? null
                                : () async {
                                    if (isDownloaded) {
                                      // Show confirmation to remove
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: const Color(0xFF18181B),
                                          title: const Text('Remove Downloads'),
                                          content: Text('Do you want to remove the downloaded songs for ${mood.displayName}?'),
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
                                        downloadService.deleteBatch(moodSongs);
                                      }
                                    } else {
                                      final apiService = ApiService();
                                      final allSongs = await apiService.getSongsByMood('');
                                      final moodSongObjects = allSongs.where((s) => moodSongs.contains(s.id)).toList();
                                      downloadService.downloadBatch(moodSongObjects, 'https://musicapi.sisganadero.online');
                                    }
                                  },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlaylistView(mood: mood),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _LibraryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: moodProvider.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing!,
          const Icon(Icons.chevron_right, color: Colors.white24),
        ],
      ),
    );
  }
}
