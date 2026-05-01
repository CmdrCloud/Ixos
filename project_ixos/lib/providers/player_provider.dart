import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

class PlayerProvider with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  Song? _currentSong;
  bool _isPlaying = false;

  PlayerProvider() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;

  Future<void> playSong(Song song, {String? baseUrl}) async {
    _currentSong = song;
    notifyListeners();
    
    try {
      print('DEBUG Playback: title="${song.title}", fileId="${song.fileId}"');
      
      String? streamUrl = song.cdnUrl;
      
      if (streamUrl == null || streamUrl.isEmpty) {
        if (song.filePath.startsWith('http')) {
          streamUrl = song.filePath;
        } else if (song.filePath.isNotEmpty) {
          final effectiveBaseUrl = baseUrl ?? 'https://musicapi.gamobo.shop';
          String cleanPath = song.filePath;
          if (cleanPath.startsWith('/')) {
            cleanPath = cleanPath.substring(1);
          }
          streamUrl = '$effectiveBaseUrl/$cleanPath';
        } else {
          // Fallback to building URL via fileId if filePath is empty
          final effectiveBaseUrl = baseUrl ?? 'https://musicapi.gamobo.shop';
          if (song.fileId.isNotEmpty) {
            String fileName = song.fileId;
            if (!fileName.endsWith('.mp3')) {
              fileName = '$fileName.mp3';
            }
            streamUrl = '$effectiveBaseUrl/music/$fileName';
          }
        }
      }

      if (streamUrl != null && streamUrl.isNotEmpty) {
        print('Attempting Final Stream URL: $streamUrl');
        
        // We set the URL and catch the 404 specifically to try a fallback if needed
        try {
          await _player.setUrl(streamUrl);
          await _player.play();
        } catch (e) {
          if (e.toString().contains('404') && !streamUrl!.contains(':3002')) {
            print('404 detected, trying fallback with port 3002...');
            String fallbackUrl = streamUrl!.replaceFirst('gamobo.shop', 'gamobo.shop:3002');
            print('Attempting Fallback URL: $fallbackUrl');
            await _player.setUrl(fallbackUrl);
            await _player.play();
          } else {
            rethrow;
          }
        }
      } else {
        print('Error: No valid stream URL or fileId for song: ${song.title}');
      }
    } catch (e) {
      debugPrint("Error playing song: $e");
    }
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
