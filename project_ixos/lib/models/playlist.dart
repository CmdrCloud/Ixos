class Playlist {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? coverUrl;
  final String visibility;
  final String? moodId;
  final int totalSongs;
  final double totalDurationS;

  Playlist({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.coverUrl,
    required this.visibility,
    this.moodId,
    this.totalSongs = 0,
    this.totalDurationS = 0,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      ownerId: (json['owner_id'] ?? json['ownerId'])?.toString() ?? '',
      name: json['name'] ?? 'Untitled Playlist',
      description: json['description'],
      coverUrl: json['cover_url'] ?? json['coverUrl'],
      visibility: json['visibility'] ?? 'private',
      moodId: json['mood_id'] ?? json['moodId'],
      totalSongs: json['total_songs'] ?? json['totalSongs'] ?? 0,
      totalDurationS: (json['total_duration_s'] ?? json['totalDurationS'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'cover_url': coverUrl,
      'visibility': visibility,
      'mood_id': moodId,
      'total_songs': totalSongs,
      'total_duration_s': totalDurationS,
    };
  }
}
