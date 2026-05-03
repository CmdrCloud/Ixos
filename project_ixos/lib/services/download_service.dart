import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

class DownloadService with ChangeNotifier {
  final Dio _dio = Dio();
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingIds = {};
  final Set<String> _downloadedIds = {};

  DownloadService() {
    _init();
  }

  Future<void> _init() async {
    await _checkDownloadedSongs();
  }

  double getProgress(String songId) => _downloadProgress[songId] ?? 0.0;
  bool isDownloading(String songId) => _downloadingIds.contains(songId);
  bool isDownloaded(String songId) => _downloadedIds.contains(songId);

  Future<void> _checkDownloadedSongs() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (await downloadDir.exists()) {
      final files = downloadDir.listSync();
      for (var file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          if (fileName.endsWith('.mp3')) {
            final songId = fileName.replaceAll('.mp3', '');
            _downloadedIds.add(songId);
          }
        }
      }
      notifyListeners();
    }
  }

  Future<String> getLocalPath(String songId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/downloads/$songId.mp3';
  }

  Future<void> downloadSong(Song song, String baseUrl) async {
    if (isDownloading(song.id) || isDownloaded(song.id)) return;

    final songUrl = _getDownloadUrl(song, baseUrl);
    if (songUrl == null) {
      debugPrint('Error: Could not generate download URL for ${song.title}');
      return;
    }

    final savePath = await getLocalPath(song.id);
    final file = File(savePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    _downloadingIds.add(song.id);
    _downloadProgress[song.id] = 0.0;
    notifyListeners();

    try {
      debugPrint('DEBUG: Downloading from $songUrl');
      await _dio.download(
        songUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgress[song.id] = received / total;
            notifyListeners();
          }
        },
      );
      _downloadedIds.add(song.id);
    } catch (e) {
      debugPrint('Error downloading song: $e');
      if (await file.exists()) {
        await file.delete();
      }
    } finally {
      _downloadingIds.remove(song.id);
      _downloadProgress.remove(song.id);
      notifyListeners();
    }
  }

  String? _getDownloadUrl(Song song, String? baseUrl) {
    String? url = song.cdnUrl;
    if (url == null || url.isEmpty) {
      if (song.filePath.startsWith('http')) {
        url = song.filePath;
      } else {
        final effectiveBaseUrl = baseUrl ?? 'https://musicapi.sisganadero.online';
        if (song.fileId.isNotEmpty) {
          String fileName = song.fileId;
          if (!fileName.endsWith('.mp3')) fileName = '$fileName.mp3';
          url = '$effectiveBaseUrl/music/$fileName';
        } else if (song.filePath.isNotEmpty) {
          String cleanPath = song.filePath;
          if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
          url = '$effectiveBaseUrl/$cleanPath';
        }
      }
    }

    if (url != null && url.startsWith('http:')) {
      url = url.replaceFirst('http:', 'https:');
    }

    return url;
  }

  Future<void> deleteDownload(String songId) async {
    final path = await getLocalPath(songId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      _downloadedIds.remove(songId);
      notifyListeners();
    }
  }

  Future<void> deleteBatch(List<String> songIds) async {
    for (var id in songIds) {
      await deleteDownload(id);
    }
  }

  Future<void> downloadBatch(List<Song> songs, String baseUrl) async {
    for (var song in songs) {
      // downloadSong already handles skip if downloaded or downloading
      await downloadSong(song, baseUrl);
    }
  }

  bool isMoodDownloaded(List<String> songIds) {
    if (songIds.isEmpty) return false;
    return songIds.every((id) => isDownloaded(id));
  }

  bool isMoodDownloading(List<String> songIds) {
    return songIds.any((id) => isDownloading(id));
  }
}
