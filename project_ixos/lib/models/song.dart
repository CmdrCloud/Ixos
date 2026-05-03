class Song {
  final String id;
  final String fileId;
  final String filePath;
  final String? cdnUrl;
  final String title;
  final String artistId;
  final String? artistName; // For convenience if joined in API
  final String? albumId;
  final String? albumTitle; // For convenience if joined in API
  final String? coverUrl;
  final int? releaseYear;
  final double durationS;
  final bool explicit;
  final int playCount;

  Song({
    required this.id,
    required this.fileId,
    required this.filePath,
    this.cdnUrl,
    required this.title,
    required this.artistId,
    this.artistName,
    this.albumId,
    this.albumTitle,
    this.coverUrl,
    this.releaseYear,
    required this.durationS,
    this.explicit = false,
    this.playCount = 0,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>?;

    // Helper to parse double safely from String or Number
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper to parse int safely from String or Number
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Migration Helper: Replace old domain with new domain to avoid SSL/Auth issues
    String? migrateUrl(String? url) {
      if (url == null) return null;
      return url.replaceAll('musicapi.gamobo.shop', 'musicapi.sisganadero.online');
    }

    final song = Song(
      id: json['id']?.toString() ?? '',
      fileId: (json['file_id'] ?? json['fileId'] ?? json['id'])?.toString() ?? '',
      filePath: migrateUrl((json['music_url'] ?? json['musicUrl'] ?? json['file_path'] ?? json['filePath'] ?? json['ruta'] ?? '')?.toString()) ?? '',
      cdnUrl: migrateUrl(json['cdn_url'] ?? json['cdnUrl'] ?? json['music_url']),
      title: json['title'] ?? metadata?['titulo'] ?? 'Unknown',
      artistId: json['artist_id']?.toString() ?? json['artistId']?.toString() ?? '',
      artistName: json['artist'] ?? json['artist_name'] ?? json['artistName'] ?? metadata?['artista'],
      albumId: json['album_id']?.toString() ?? json['albumId']?.toString(),
      albumTitle: json['album_title'] ?? json['albumTitle'] ?? metadata?['album'],
      coverUrl: migrateUrl(json['cover_url'] ?? json['coverUrl']),
      releaseYear: parseInt(json['release_year'] ?? json['releaseYear'] ?? metadata?['anio']),
      durationS: parseDouble(json['duration_s'] ?? json['durationS'] ?? json['duracion']),
      explicit: json['explicit'] == true || json['explicit'] == 1,
      playCount: parseInt(json['play_count'] ?? json['playCount']),
    );

    print('Parsed Song [${song.title}]: file_path="${song.filePath}", cdn_url="${song.cdnUrl}"');
    return song;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_id': fileId,
      'file_path': filePath,
      'cdn_url': cdnUrl,
      'title': title,
      'artist_id': artistId,
      'album_id': albumId,
      'cover_url': coverUrl,
      'release_year': releaseYear,
      'duration_s': durationS,
      'explicit': explicit,
      'play_count': playCount,
    };
  }
}
