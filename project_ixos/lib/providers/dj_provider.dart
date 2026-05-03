import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

class DeckState {
  late final AudioPlayer player;
  late final AndroidEqualizer equalizer;
  
  Song? currentSong;
  double volume = 1.0;
  double tempo = 1.0;
  double eqLow = 0.0;
  double eqMid = 0.0;
  double eqHigh = 0.0;
  double bpm = 0.0;
  bool isPlaying = false;

  AndroidEqualizerParameters? _params;

  DeckState() {
    equalizer = AndroidEqualizer();
    player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [
          equalizer,
        ],
      ),
    );
    
    // Enable the equalizer
    equalizer.setEnabled(true);

    player.playerStateStream.listen((state) {
      isPlaying = state.playing;
    });
  }

  Future<void> loadSong(Song song, String? baseUrl) async {
    print('DEBUG: Loading song ${song.title} to deck...');
    currentSong = song;
    
    String? url = song.filePath;
    if (url.isEmpty) {
       url = 'https://musicapi.sisganadero.online/music/${song.fileId}.mp3';
    } else if (!url.startsWith('http')) {
      url = '${baseUrl ?? 'https://musicapi.sisganadero.online'}/$url';
    }
    
    url = url.replaceAll('musicapi.gamobo.shop', 'musicapi.sisganadero.online');
    
    try {
      print('DEBUG: Deck Stream URL: $url');
      await player.setUrl(url);
      bpm = 120.0 + (song.id.hashCode % 30);
      print('DEBUG: Deck loaded successfully: ${song.title}');
    } catch (e) {
      print("DEBUG ERROR loading to deck: $e");
    }
  }

  void updateEq() async {
    try {
      _params ??= await equalizer.parameters;
      final bands = _params!.bands;
      final minLvl = _params!.minDecibels;
      final maxLvl = _params!.maxDecibels;

      double mapGain(double value) {
        // Map -10..10 to minLvl..maxLvl
        // Range is 20 units. (value + 10) / 20 maps -10..10 to 0..1
        return (value + 10) * (maxLvl - minLvl) / 20 + minLvl;
      }

      if (bands.length >= 5) {
        await bands[0].setGain(mapGain(eqLow));
        await bands[2].setGain(mapGain(eqMid));
        await bands[4].setGain(mapGain(eqHigh));
      } else if (bands.length >= 3) {
        await bands[0].setGain(mapGain(eqLow));
        await bands[1].setGain(mapGain(eqMid));
        await bands[2].setGain(mapGain(eqHigh));
      } else if (bands.isNotEmpty) {
        // Fallback for single band or unusual configurations
        await bands[0].setGain(mapGain(eqLow));
      }
    } catch (e) {
      debugPrint("EQ Update error: $e");
    }
  }

  void dispose() {
    player.dispose();
  }
}

class DjProvider with ChangeNotifier {
  final DeckState deckA = DeckState();
  final DeckState deckB = DeckState();

  DjProvider() {
    deckA.player.playerStateStream.listen((_) => notifyListeners());
    deckB.player.playerStateStream.listen((_) => notifyListeners());
  }

  void setVolume(bool isDeckA, double value) {
    if (isDeckA) {
      deckA.volume = value;
      deckA.player.setVolume(value);
    } else {
      deckB.volume = value;
      deckB.player.setVolume(value);
    }
    notifyListeners();
  }

  void setTempo(bool isDeckA, double value) {
    if (isDeckA) {
      deckA.tempo = value;
      deckA.player.setSpeed(value);
    } else {
      deckB.tempo = value;
      deckB.player.setSpeed(value);
    }
    notifyListeners();
  }

  double getDisplayBpm(bool isDeckA) {
    final deck = isDeckA ? deckA : deckB;
    return deck.bpm * deck.tempo;
  }

  void setEq(bool isDeckA, String band, double value) {
    final deck = isDeckA ? deckA : deckB;
    if (band == 'low') deck.eqLow = value;
    if (band == 'mid') deck.eqMid = value;
    if (band == 'high') deck.eqHigh = value;
    
    deck.updateEq();
    notifyListeners();
  }

  Future<void> loadToDeck(bool isDeckA, Song song, String? baseUrl) async {
    if (isDeckA) {
      await deckA.loadSong(song, baseUrl);
    } else {
      await deckB.loadSong(song, baseUrl);
    }
    notifyListeners();
  }

  void togglePlay(bool isDeckA) {
    final deck = isDeckA ? deckA : deckB;
    if (deck.player.playing) {
      deck.player.pause();
    } else {
      deck.player.play();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    deckA.dispose();
    deckB.dispose();
    super.dispose();
  }
}
