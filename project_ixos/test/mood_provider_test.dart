import 'package:flutter_test/flutter_test.dart';
import 'package:project_end/providers/mood_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoodProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial mood songs should be empty', () {
      final provider = MoodProvider();
      expect(provider.getUserSongsForMood('1'), isEmpty);
    });

    test('Adding song to mood updates state', () {
      final provider = MoodProvider();
      provider.addSongToMood('1', 'song_a');
      expect(provider.getUserSongsForMood('1'), contains('song_a'));
      expect(provider.isSongInMood('1', 'song_a'), isTrue);
    });

    test('Removing song from mood updates state', () {
      final provider = MoodProvider();
      provider.addSongToMood('1', 'song_a');
      provider.removeSongFromMood('1', 'song_a');
      expect(provider.getUserSongsForMood('1'), isEmpty);
      expect(provider.isSongInMood('1', 'song_a'), isFalse);
    });

    test('Persistence check (simulated)', () async {
      SharedPreferences.setMockInitialValues({
        'user_mood_songs': '{"1":["song_a"]}'
      });
      final provider = MoodProvider();
      // Wait for the async load
      await Future.delayed(Duration.zero);
      expect(provider.getUserSongsForMood('1'), contains('song_a'));
    });
  });
}
