import 'package:flutter/material.dart';
import '../models/mood.dart';
import '../screens/playlist_view.dart';
import '../providers/mood_provider.dart';
import '../providers/auth_provider.dart';
import '../services/download_service.dart';
import '../services/api_service.dart';
import '../models/song.dart';
import 'package:provider/provider.dart';

class PlaylistTile extends StatelessWidget {
  const PlaylistTile({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  final Mood mood;
  final bool isSelected;
  final VoidCallback onTap;

  IconData _parseIconName(String iconName) {
    switch (iconName) {
      case 'sentiment_satisfied':
        return Icons.sentiment_satisfied;
      case 'cloud':
        return Icons.cloud;
      case 'headphones':
        return Icons.headphones;
      case 'bolt':
        return Icons.bolt;
      case 'spa':
        return Icons.spa;
      case 'local_bar':
        return Icons.local_bar;
      case 'nightlight':
        return Icons.nightlight;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.music_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodProvider = context.watch<MoodProvider>();
    final downloadService = context.watch<DownloadService>();
    final moodSongs = moodProvider.getUserSongsForMood(mood.id);
    final isDownloaded = downloadService.isMoodDownloaded(moodSongs);
    final isDownloading = downloadService.isMoodDownloading(moodSongs);

    return GestureDetector(
      onTap: () {
        onTap();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlaylistView(mood: mood),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: mood.gradient,
          ),
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.5), width: 2)
              : null,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: mood.gradient.last.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      _parseIconName(mood.iconName),
                      color: Colors.white.withOpacity(0.7),
                      size: 30,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    mood.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mixed for you',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (moodSongs.isNotEmpty)
              Positioned(
                bottom: 8,
                right: 8,
                child: IconButton(
                  icon: isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          isDownloaded ? Icons.download_done : Icons.download,
                          color: isDownloaded ? Colors.greenAccent : Colors.white70,
                          size: 20,
                        ),
                  onPressed: isDownloading
                      ? null
                      : () async {
                          if (isDownloaded) {
                            // Long press would be better but let's stick to a simple toggle or confirmation
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF18181B),
                                title: const Text('Remove Downloads'),
                                content: Text('Remove downloads for ${mood.displayName}?'),
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
                          } else if (moodSongs.isNotEmpty) {
                            final apiService = ApiService();
                            final allSongs = await apiService.getSongsByMood('');
                            final moodSongObjects = allSongs.where((s) => moodSongs.contains(s.id)).toList();
                            downloadService.downloadBatch(moodSongObjects, 'https://musicapi.sisganadero.online');
                          }
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
