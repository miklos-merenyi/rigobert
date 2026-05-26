import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'game_colors.dart';

// A-major triad from the pentatonic scale: A4, C#5, E5
const _kFrequencies = {
  GameColor.red:   440.0, // A4
  GameColor.green: 554.4, // C#5
  GameColor.blue:  659.3, // E5
};

Uint8List _buildWav(double frequency, int durationMs) {
  const sampleRate = 44100;
  final numSamples = (sampleRate * durationMs / 1000).round();
  final dataBytes = numSamples * 2;
  final buf = ByteData(44 + dataBytes);

  void ascii(int off, String s) {
    for (int i = 0; i < s.length; i++) {
      buf.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  buf.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  buf.setUint32(16, 16, Endian.little);
  buf.setUint16(20, 1, Endian.little);           // PCM
  buf.setUint16(22, 1, Endian.little);           // mono
  buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  buf.setUint32(40, dataBytes, Endian.little);

  final attackSamples = (sampleRate * 0.010).round(); // 10 ms attack
  final releaseSamples = (sampleRate * 0.030).round(); // 30 ms release

  for (int i = 0; i < numSamples; i++) {
    final attack = i < attackSamples ? i / attackSamples : 1.0;
    final release = i > numSamples - releaseSamples
        ? (numSamples - i) / releaseSamples
        : 1.0;
    final t = i / sampleRate;
    final v = (sin(2 * pi * frequency * t) * attack * release * 28000)
        .round()
        .clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, v, Endian.little);
  }

  return buf.buffer.asUint8List();
}

class SoundPlayer {
  final Map<GameColor, AudioPlayer> _players = {};
  final Map<GameColor, Uint8List> _tones = {};
  final _melodyPlayer = AudioPlayer();

  SoundPlayer() {
    _melodyPlayer
      ..setReleaseMode(ReleaseMode.stop)
      ..setVolume(0.75);
    for (final color in GameColor.values) {
      _players[color] = AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop)
        ..setVolume(0.7);
      // Pre-generate: 1.5 s for interactive presses, trimmed in sequence
      _tones[color] = _buildWav(_kFrequencies[color]!, 1500);
    }
  }

  Future<void> play(GameColor color) async {
    final p = _players[color]!;
    await p.stop();
    await p.play(BytesSource(_tones[color]!));
  }

  Future<void> stop(GameColor color) => _players[color]!.stop();

  Future<void> playSet(Set<GameColor> colors) async {
    for (final c in colors) {
      await play(c);
    }
  }

  Future<void> stopAll() async {
    for (final p in _players.values) {
      await p.stop();
    }
  }

  /// Play a single melody note at [frequency] Hz for [durationMs] ms.
  Future<void> playNote(double frequency, int durationMs) async {
    final wav = _buildWav(frequency, durationMs);
    await _melodyPlayer.stop();
    await _melodyPlayer.play(BytesSource(wav));
  }

  Future<void> stopMelody() => _melodyPlayer.stop();

  void dispose() {
    _melodyPlayer.dispose();
    for (final p in _players.values) {
      p.dispose();
    }
  }
}
