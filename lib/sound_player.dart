import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'game_colors.dart';

// F minor pentatonic, one note per button combination (low → high complexity).
//   Single:  Red=F4, Green=G4, Blue=Bb4
//   Pairs:   R+G=C5, R+B=D5, G+B=F5
//   All:     R+G+B=G5
const _kComboAsset = <String, String>{
  '0':     'assets/sounds/combo_0.mp3',     // F4  — Red
  '1':     'assets/sounds/combo_1.mp3',     // G4  — Green
  '2':     'assets/sounds/combo_2.mp3',     // Bb4 — Blue
  '0-1':   'assets/sounds/combo_0-1.mp3',   // C5  — Red + Green
  '0-2':   'assets/sounds/combo_0-2.mp3',   // D5  — Red + Blue
  '1-2':   'assets/sounds/combo_1-2.mp3',   // F5  — Green + Blue
  '0-1-2': 'assets/sounds/combo_0-1-2.mp3', // G5  — All three
};

// Melody note frequencies → combo asset (same pitches, reuse the files).
final _kMelodyAsset = <double, String>{
  349.23: 'assets/sounds/combo_0.mp3',
  392.00: 'assets/sounds/combo_1.mp3',
  466.16: 'assets/sounds/combo_2.mp3',
  523.25: 'assets/sounds/combo_0-1.mp3',
  587.33: 'assets/sounds/combo_0-2.mp3',
  698.46: 'assets/sounds/combo_1-2.mp3',
};

/// Canonical key for a combo set (sorted by enum index).
String _key(Set<GameColor> combo) {
  final sorted = combo.toList()..sort((a, b) => a.index - b.index);
  return sorted.map((c) => c.index.toString()).join('-');
}

// Debug logging — keep in sync with kInputDebug in game_screen.dart.
const bool _kSoundDebug = true;
String _sts() => DateTime.now().toIso8601String().split('T').last;

// ── SoundPlayer ────────────────────────────────────────────────────────────
//
// Instrument notes (combo + melody) play through SoLoud: a self-contained
// C++ audio engine (not a wrapper around Android/iOS MediaPlayer/AVAudioPlayer)
// that decodes each clip to PCM once and mixes raw samples itself. Unlike
// MediaPlayer/ExoPlayer (audioplayers), it does not introduce MP3 decoder
// padding or buffer-teardown pops at the tail — which is what caused the
// end-of-sound clicking. Fail + R2D2 one-shots stay on audioplayers.

class SoundPlayer {
  static final SoLoud _engine = SoLoud.instance;

  // asset path → loaded source (resolved once preloading completes).
  final Map<String, AudioSource> _sources = {};
  Future<void>? _loading;

  // One-shot effects stay on audioplayers (occasional, not latency-critical).
  final _failPlayer = AudioPlayer();
  final _r2d2Player = AudioPlayer();
  final _r2d2Rng    = Random();

  // Each combo touch gets a 400 ms slot so rapid presses don't overlap.
  static const _slotMs = 400;
  final _comboQueue  = <Set<GameColor>>[];
  bool  _comboActive = false;

  SoundPlayer() {
    _failPlayer.setReleaseMode(ReleaseMode.release);
    _failPlayer.setVolume(0.9);
    _r2d2Player.setReleaseMode(ReleaseMode.release);
    _r2d2Player.setVolume(0.9);
    _loading = _preload();
  }

  /// Completes once every instrument clip has been decoded into the pool.
  /// The intro waits on this so its opening notes aren't dropped or bunched
  /// into a chorus while the samples are still loading.
  Future<void> get ready => _loading ?? Future<void>.value();

  /// Decode every instrument clip into the engine once, up front.
  Future<void> _preload() async {
    if (!_engine.isInitialized) {
      await _engine.init();
      _engine.setMaxActiveVoiceCount(8); // notes may overlap without cutting each other off
    }
    for (final asset in _kComboAsset.values) {
      if (_sources.containsKey(asset)) continue;
      try {
        _sources[asset] = await _engine.loadAsset(asset);
      } catch (e) {
        debugPrint('SoundPlayer: failed to load $asset ($e)');
      }
    }
  }

  /// Returns the loaded source for [asset], waiting on preload if still in flight.
  Future<AudioSource?> _sourceFor(String asset) async {
    if (_sources.containsKey(asset)) return _sources[asset];
    await _loading;
    return _sources[asset];
  }

  // ── Combo / instrument ───────────────────────────────────────────────────

  Future<void> playCombo(Set<GameColor> combo) async {
    if (combo.isEmpty) return;
    if (_comboActive) {
      if (_comboQueue.length < 3) {
        _comboQueue.add(Set.of(combo));
        if (_kSoundDebug) {
          debugPrint('[SOUND ${_sts()}] playCombo ${_key(combo)} → QUEUED '
              '(slot busy, depth=${_comboQueue.length}, plays in ≤${_slotMs}ms)');
        }
      } else if (_kSoundDebug) {
        debugPrint('[SOUND ${_sts()}] playCombo ${_key(combo)} → DROPPED (queue full)');
      }
      return;
    }
    await _startComboSlot(combo);
  }

  Future<void> _startComboSlot(Set<GameColor> combo) async {
    final asset = _kComboAsset[_key(combo)];
    if (asset == null) return;
    _comboActive = true;
    final source = await _sourceFor(asset);
    if (_kSoundDebug) {
      debugPrint('[SOUND ${_sts()}] ▶ PLAY combo=${_key(combo)} '
          'asset=${asset.split('/').last} loaded=${source != null}');
    }
    if (source != null) _engine.play(source);
    Future.delayed(const Duration(milliseconds: _slotMs), _onComboSlotEnd);
  }

  void _onComboSlotEnd() {
    _comboActive = false;
    if (_comboQueue.isNotEmpty) {
      final next = _comboQueue.removeAt(0);
      if (_kSoundDebug) {
        debugPrint('[SOUND ${_sts()}] slot freed → dequeue ${_key(next)} '
            '(was queued; remaining=${_comboQueue.length})');
      }
      _startComboSlot(next);
    }
  }

  Future<void> stopCombo() async {
    _comboQueue.clear();
    _comboActive = false;
    // Clips are short and play to completion; nothing to stop.
  }

  /// Convenience alias used during sequence display.
  Future<void> playSet(Set<GameColor> colors) => playCombo(colors);

  // ── Melody (intro) ───────────────────────────────────────────────────────

  /// Play a melody note by frequency — reuses the bundled combo clips.
  Future<void> playNote(double frequency, int durationMs) async {
    // Find the closest asset frequency (within 1 Hz tolerance).
    String? asset;
    for (final entry in _kMelodyAsset.entries) {
      if ((entry.key - frequency).abs() < 1.0) { asset = entry.value; break; }
    }
    if (asset == null) return;
    final source = await _sourceFor(asset);
    if (_kSoundDebug) {
      debugPrint('[SOUND ${_sts()}] ♪ NOTE freq=${frequency.toStringAsFixed(0)} '
          'asset=${asset.split('/').last} loaded=${source != null}');
    }
    if (source != null) _engine.play(source);
  }

  Future<void> stopMelody() async {
    // Melody notes are short and play to completion.
  }

  // ── Fail & R2D2 ─────────────────────────────────────────────────────────

  Future<void> playFail() async {
    _comboQueue.clear();
    _comboActive = false;
    await _failPlayer.play(AssetSource('sounds/fail.mp3'));
  }

  Future<void> playR2D2Beep() async {
    final i = _r2d2Rng.nextInt(16);
    _r2d2Player.play(AssetSource('sounds/r2d2_$i.mp3'));
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> stopAll() async {
    _comboQueue.clear();
    _comboActive = false;
    await Future.wait([
      _failPlayer.stop(),
      _r2d2Player.stop(),
    ]);
  }

  void dispose() {
    // Only dispose our own loaded sources, not the whole (app-wide,
    // singleton) SoLoud engine — the game screen's SoundPlayer is
    // recreated on every visit, and re-initing the engine each time is
    // unnecessary churn.
    for (final source in _sources.values) {
      unawaited(_engine.disposeSource(source));
    }
    _sources.clear();
    _failPlayer.dispose();
    _r2d2Player.dispose();
  }
}
