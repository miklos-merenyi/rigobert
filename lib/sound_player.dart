import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'game_colors.dart';

// F minor pentatonic, one note per button combination (low → high complexity).
//   Single:  Red=F4, Green=G4, Blue=Bb4
//   Pairs:   R+G=C5, R+B=D5, G+B=F5
//   All:     R+G+B=G5
const _kComboAsset = <String, String>{
  '0':     'sounds/combo_0.mp3',     // F4  — Red
  '1':     'sounds/combo_1.mp3',     // G4  — Green
  '2':     'sounds/combo_2.mp3',     // Bb4 — Blue
  '0-1':   'sounds/combo_0-1.mp3',   // C5  — Red + Green
  '0-2':   'sounds/combo_0-2.mp3',   // D5  — Red + Blue
  '1-2':   'sounds/combo_1-2.mp3',   // F5  — Green + Blue
  '0-1-2': 'sounds/combo_0-1-2.mp3', // G5  — All three
};

// Melody note frequencies → combo asset (same pitches, reuse the files).
final _kMelodyAsset = <double, String>{
  349.23: 'sounds/combo_0.mp3',
  392.00: 'sounds/combo_1.mp3',
  466.16: 'sounds/combo_2.mp3',
  523.25: 'sounds/combo_0-1.mp3',
  587.33: 'sounds/combo_0-2.mp3',
  698.46: 'sounds/combo_1-2.mp3',
};

/// Canonical key for a combo set (sorted by enum index).
String _key(Set<GameColor> combo) {
  final sorted = combo.toList()..sort((a, b) => a.index - b.index);
  return sorted.map((c) => c.index.toString()).join('-');
}

// ── SoundPlayer ────────────────────────────────────────────────────────────

class SoundPlayer {
  final _comboPlayer  = AudioPlayer();
  final _melodyPlayer = AudioPlayer();
  final _failPlayer   = AudioPlayer();
  final _r2d2Player   = AudioPlayer();
  final _r2d2Rng      = Random();

  // Each combo touch gets a 400 ms slot so rapid presses don't overlap.
  static const _slotMs = 400;
  final _comboQueue  = <Set<GameColor>>[];
  bool  _comboActive = false;

  SoundPlayer() {
    for (final p in [_comboPlayer, _melodyPlayer, _failPlayer, _r2d2Player]) {
      p.setReleaseMode(ReleaseMode.release);
      p.setVolume(0.9);
    }
  }

  // ── Combo / instrument ───────────────────────────────────────────────────

  Future<void> playCombo(Set<GameColor> combo) async {
    if (combo.isEmpty) return;
    if (_comboActive) {
      if (_comboQueue.length < 3) _comboQueue.add(Set.of(combo));
      return;
    }
    await _startComboSlot(combo);
  }

  Future<void> _startComboSlot(Set<GameColor> combo) async {
    final asset = _kComboAsset[_key(combo)];
    if (asset == null) return;
    _comboActive = true;
    await _comboPlayer.play(AssetSource(asset));
    Future.delayed(const Duration(milliseconds: _slotMs), _onComboSlotEnd);
  }

  void _onComboSlotEnd() {
    _comboActive = false;
    if (_comboQueue.isNotEmpty) {
      _startComboSlot(_comboQueue.removeAt(0));
    }
  }

  Future<void> stopCombo() async {
    _comboQueue.clear();
    _comboActive = false;
    await _comboPlayer.stop();
  }

  /// Convenience alias used during sequence display.
  Future<void> playSet(Set<GameColor> colors) => playCombo(colors);

  // ── Melody (intro) ───────────────────────────────────────────────────────

  /// Play a melody note by frequency — reuses the bundled combo MP3s.
  Future<void> playNote(double frequency, int durationMs) async {
    // Find the closest asset frequency (within 1 Hz tolerance).
    String? asset;
    for (final entry in _kMelodyAsset.entries) {
      if ((entry.key - frequency).abs() < 1.0) { asset = entry.value; break; }
    }
    if (asset == null) return;
    await _melodyPlayer.play(AssetSource(asset));
  }

  Future<void> stopMelody() => _melodyPlayer.stop();

  // ── Fail & R2D2 ─────────────────────────────────────────────────────────

  Future<void> playFail() async {
    _comboQueue.clear();
    _comboActive = false;
    await _comboPlayer.stop();
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
      _comboPlayer.stop(),
      _melodyPlayer.stop(),
      _failPlayer.stop(),
      _r2d2Player.stop(),
    ]);
  }

  void dispose() {
    _comboPlayer.dispose();
    _melodyPlayer.dispose();
    _failPlayer.dispose();
    _r2d2Player.dispose();
  }
}
