import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/mood_provider.dart';
import '../models/song.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final moodProvider = context.watch<MoodProvider>();
    final song = playerProvider.currentSong;

    if (song == null) return const Scaffold();

    return Scaffold(
      backgroundColor: moodProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Playing now', style: TextStyle(fontSize: 14, color: Colors.white54)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => _showQueue(context, playerProvider),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              moodProvider.currentGradient.first.withOpacity(0.3),
              moodProvider.backgroundColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Album Art
              Hero(
                tag: 'album_art',
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey[900],
                      boxShadow: [
                        BoxShadow(
                          color: moodProvider.currentGradient.first.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      image: song.coverUrl != null
                          ? DecorationImage(
                              image: NetworkImage(song.coverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: song.coverUrl == null
                        ? const Icon(Icons.music_note, size: 100, color: Colors.white24)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Song Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          song.artistName ?? 'Unknown Artist',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Progress Bar
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.2),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: playerProvider.duration.inMilliseconds > 0
                      ? playerProvider.position.inMilliseconds / playerProvider.duration.inMilliseconds
                      : 0.0,
                  onChanged: (v) {
                    final newPos = Duration(milliseconds: (v * playerProvider.duration.inMilliseconds).toInt());
                    playerProvider.seek(newPos);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(playerProvider.position),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    Text(_formatDuration(playerProvider.duration),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: playerProvider.isShuffle ? Colors.blue : Colors.white54,
                    ),
                    onPressed: () => playerProvider.toggleShuffle(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 40),
                    onPressed: () => playerProvider.skipPrevious(),
                  ),
                  GestureDetector(
                    onTap: () => playerProvider.togglePlay(),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        playerProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 40,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 40),
                    onPressed: () => playerProvider.skipNext(),
                  ),
                  IconButton(
                    icon: Icon(
                      playerProvider.repeatMode == PlayerRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                      color: playerProvider.repeatMode != PlayerRepeatMode.none ? Colors.blue : Colors.white54,
                    ),
                    onPressed: () => playerProvider.nextRepeatMode(),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.toString();
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _showQueue(BuildContext context, PlayerProvider playerProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Queue',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${playerProvider.queue.length} songs',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              playerProvider.clearQueue();
                              setModalState(() {});
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.redAccent, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    Expanded(
                      child: Theme(
                        data: ThemeData(
                          canvasColor: Colors.transparent,
                        ),
                        child: ReorderableListView.builder(
                          scrollController: scrollController,
                          itemCount: playerProvider.queue.length,
                          padding: const EdgeInsets.only(bottom: 40),
                          onReorder: (oldIndex, newIndex) {
                            playerProvider.reorderQueue(oldIndex, newIndex);
                            setModalState(() {});
                          },
                          itemBuilder: (context, index) {
                            final song = playerProvider.queue[index];
                            final isCurrent = index == playerProvider.currentIndex;

                            return Container(
                              key: ValueKey('${song.id}_$index'),
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCurrent ? Colors.white.withOpacity(0.05) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: Colors.white10,
                                    child: song.coverUrl != null
                                        ? Image.network(song.coverUrl!, fit: BoxFit.cover)
                                        : const Icon(Icons.music_note, color: Colors.white24),
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  style: TextStyle(
                                    color: isCurrent ? Colors.blueAccent : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  song.artistName ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.drag_handle, color: Colors.white24),
                                onTap: () {
                                  playerProvider.jumpToQueueItem(index);
                                  setModalState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
