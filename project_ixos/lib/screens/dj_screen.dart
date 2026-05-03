import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import '../providers/dj_provider.dart';
import '../providers/mood_provider.dart';

class DjScreen extends StatelessWidget {
  const DjScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('DJ MODE', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const _DeckView(isDeckA: true),
                Container(width: 1, color: Colors.white10),
                const _DeckView(isDeckA: false),
              ],
            ),
          ),
          const _MixerControls(),
        ],
      ),
    );
  }
}

class _DeckView extends StatelessWidget {
  final bool isDeckA;
  const _DeckView({required this.isDeckA});

  @override
  Widget build(BuildContext context) {
    final djProvider = context.watch<DjProvider>();
    final deck = isDeckA ? djProvider.deckA : djProvider.deckB;

    return Expanded(
      child: Column(
        children: [
          const SizedBox(height: 10),
          // BPM Display (Updated to show real-time calculated BPM)
          Text(
            '${djProvider.getDisplayBpm(isDeckA).toStringAsFixed(1)} BPM',
            style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: Row(
              children: [
                // BPM/TEMPO Slider on the left
                Column(
                  children: [
                    const Text('BPM', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: deck.tempo,
                          min: 0.5,
                          max: 1.5,
                          activeColor: Colors.blueAccent,
                          onChanged: (v) => djProvider.setTempo(isDeckA, v),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Central Disk and Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white10, width: 2),
                          gradient: const SweepGradient(colors: [Colors.black, Color(0xFF27272A), Colors.black]),
                        ),
                        child: Icon(
                          Icons.album, 
                          size: 50, 
                          color: deck.isPlaying ? Colors.blueAccent.withOpacity(0.5) : Colors.white10
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          deck.currentSong?.title ?? 'No Song',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // VOLUME Slider on the right
                Column(
                  children: [
                    const Text('VOL', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: deck.volume,
                          min: 0.0,
                          max: 1.0,
                          activeColor: Colors.greenAccent,
                          onChanged: (v) => djProvider.setVolume(isDeckA, v),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Play/Pause
          IconButton(
            icon: Icon(
              deck.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, 
              size: 54, 
              color: Colors.white
            ),
            onPressed: () => djProvider.togglePlay(isDeckA),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _MixerControls extends StatelessWidget {
  const _MixerControls();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        color: Color(0xFF09090B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _EqGroup(isDeckA: true),
              const Text('EQ', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
              _EqGroup(isDeckA: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _EqGroup extends StatelessWidget {
  final bool isDeckA;
  const _EqGroup({required this.isDeckA});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EqKnob(isDeckA: isDeckA, band: 'low', label: 'L'),
        const SizedBox(width: 8),
        _EqKnob(isDeckA: isDeckA, band: 'mid', label: 'M'),
        const SizedBox(width: 8),
        _EqKnob(isDeckA: isDeckA, band: 'high', label: 'H'),
      ],
    );
  }
}

class _EqKnob extends StatelessWidget {
  final bool isDeckA;
  final String band;
  final String label;

  const _EqKnob({required this.isDeckA, required this.band, required this.label});

  @override
  Widget build(BuildContext context) {
    final djProvider = context.watch<DjProvider>();
    final deck = isDeckA ? djProvider.deckA : djProvider.deckB;
    
    double val = 0.0;
    if (band == 'low') val = deck.eqLow;
    if (band == 'mid') val = deck.eqMid;
    if (band == 'high') val = deck.eqHigh;

    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: SleekCircularSlider(
            appearance: CircularSliderAppearance(
              size: 40,
              startAngle: 150,
              angleRange: 240,
              customColors: CustomSliderColors(
                progressBarColor: Colors.blueAccent, 
                trackColor: Colors.white10,
                hideShadow: true,
              ),
              customWidths: CustomSliderWidths(progressBarWidth: 3, trackWidth: 2, handlerSize: 0),
            ),
            min: -10,
            max: 10,
            initialValue: val,
            onChange: (v) => djProvider.setEq(isDeckA, band, v),
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }
}
