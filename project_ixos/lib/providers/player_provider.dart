import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import '../services/download_service.dart';

enum PlayerRepeatMode { none, one, all }

class PlayerProvider with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  DownloadService? _downloadService;
  
  List<Song> _queue = [];
  int _currentIndex = -1;
  
  bool _isShuffle = false;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.none;
  
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;

  PlayerProvider() {
    _initAudioSession();

    _player.processingStateStream.listen((state) {
      print('DEBUG Player Processing State: $state');
      _isLoading = (state == ProcessingState.loading || state == ProcessingState.buffering);
      if (state == ProcessingState.completed) {
        skipNext();
      }
      notifyListeners();
    });

    _player.playerStateStream.listen((state) {
      print('DEBUG Player Playing: ${state.playing}');
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace st) {
      print('DEBUG CRITICAL Playback Error: $e');
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void updateDownloadService(DownloadService ds) {
    _downloadService = ds;
  }

  // Getters
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  List<Song> get queue => _queue;
  bool get isPlaying => _player.playing;
  bool get isLoading => _isLoading;
  bool get isShuffle => _isShuffle;
  PlayerRepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  int get currentIndex => _currentIndex;

  // Set the entire queue and play a specific song
  Future<void> setQueue(List<Song> songs, {int initialIndex = 0, String? baseUrl}) async {
    _queue = List.from(songs);
    _currentIndex = initialIndex;
    if (_queue.isNotEmpty) {
      await _loadAndPlay(_queue[_currentIndex], baseUrl: baseUrl);
    }
    notifyListeners();
  }

  // Play a single song
  Future<void> playSong(Song song, {String? baseUrl}) async {
    int index = _queue.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      _currentIndex = index;
    } else {
      _queue.insert(_currentIndex + 1, song);
      _currentIndex++;
    }
    await _loadAndPlay(song, baseUrl: baseUrl);
    notifyListeners();
  }

  // Add a song to the end of the queue
  void addToQueue(Song song) {
    _queue.add(song);
    if (_currentIndex == -1) {
      _currentIndex = 0;
      _loadAndPlay(song);
    }
    notifyListeners();
  }

  Future<void> _loadAndPlay(Song song, {String? baseUrl}) async {
    try {
      if (_downloadService != null && _downloadService!.isDownloaded(song.id)) {
        final localPath = await _downloadService!.getLocalPath(song.id);
        print('DEBUG: Playing from local file: $localPath');
        await _player.setFilePath(localPath);
      } else {
        String? streamUrl = _getStreamUrl(song, baseUrl);
        if (streamUrl != null) {
          print('DEBUG: Setting URL: $streamUrl');
          await _player.setUrl(streamUrl);
        } else {
          print('DEBUG Error: No stream URL generated for ${song.title}');
          return;
        }
      }
      print('DEBUG: Resource set successful, starting play...');
      await _player.play();
    } catch (e) {
      print("DEBUG Error in _loadAndPlay: $e");
    }
  }

  String? _getStreamUrl(Song song, String? baseUrl) {
    String? streamUrl = song.cdnUrl;
    if (streamUrl == null || streamUrl.isEmpty) {
      if (song.filePath.startsWith('http')) {
        streamUrl = song.filePath;
      } else {
        final effectiveBaseUrl = baseUrl ?? 'https://musicapi.sisganadero.online';
        if (song.fileId.isNotEmpty) {
          String fileName = song.fileId;
          if (!fileName.endsWith('.mp3')) fileName = '$fileName.mp3';
          streamUrl = '$effectiveBaseUrl/music/$fileName';
        } else if (song.filePath.isNotEmpty) {
          String cleanPath = song.filePath;
          if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
          streamUrl = '$effectiveBaseUrl/$cleanPath';
        }
      }
    }

    // Force HTTPS for Android
    if (streamUrl != null && streamUrl.startsWith('http:')) {
      streamUrl = streamUrl.replaceFirst('http:', 'https:');
    }

    return streamUrl;
  }

  void togglePlay() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    notifyListeners();
  }

  void seek(Duration pos) {
    _player.seek(pos);
  }

  void jumpToQueueItem(int index) {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      _loadAndPlay(_queue[_currentIndex]);
      notifyListeners();
    }
  }

  void skipNext() {
    if (_queue.isEmpty) return;
    
    if (_repeatMode == PlayerRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }

    if (_isShuffle) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch) % _queue.length;
    } else {
      _currentIndex++;
      if (_currentIndex >= _queue.length) {
        if (_repeatMode == PlayerRepeatMode.all) {
          _currentIndex = 0;
        } else {
          _currentIndex = _queue.length - 1;
          _player.stop();
          return;
        }
      }
    }
    _loadAndPlay(_queue[_currentIndex]);
    notifyListeners();
  }

  void skipPrevious() {
    if (_queue.isEmpty) return;
    
    if (_position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else {
      _currentIndex--;
      if (_currentIndex < 0) {
        _currentIndex = _repeatMode == PlayerRepeatMode.all ? _queue.length - 1 : 0;
      }
      _loadAndPlay(_queue[_currentIndex]);
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void nextRepeatMode() {
    _repeatMode = PlayerRepeatMode.values[(_repeatMode.index + 1) % PlayerRepeatMode.values.length];
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final Song item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    notifyListeners();
  }

  void clearQueue() {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      final current = _queue[_currentIndex];
      _queue = [current];
      _currentIndex = 0;
    } else {
      _queue = [];
      _currentIndex = -1;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
