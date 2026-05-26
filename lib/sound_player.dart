import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'game_colors.dart';

// F minor pentatonic, one note per button combination (low → high complexity).
//   Single:  Red=F4, Green=G4, Blue=Bb4
//   Pairs:   R+G=C5, R+B=D5, G+B=F5
//   All:     R+G+B=G5
const _kComboFreq = <String, double>{
  '0':     349.23, // F4  — Red
  '1':     392.00, // G4  — Green
  '2':     466.16, // Bb4 — Blue
  '0-1':   523.25, // C5  — Red + Green
  '0-2':   587.33, // D5  — Red + Blue
  '1-2':   698.46, // F5  — Green + Blue
  '0-1-2': 783.99, // G5  — All three
};

/// Canonical key for a combo set (sorted by enum index).
String _key(Set<GameColor> combo) {
  final sorted = combo.toList()..sort((a, b) => a.index - b.index);
  return sorted.map((c) => c.index.toString()).join('-');
}

// ── WAV synthesis ──────────────────────────────────────────────────────────

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
  buf.setUint16(20, 1, Endian.little);  // PCM
  buf.setUint16(22, 1, Endian.little);  // mono
  buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  buf.setUint32(40, dataBytes, Endian.little);

  final attackSamples  = (sampleRate * 0.010).round();
  final releaseSamples = (sampleRate * 0.030).round();

  for (int i = 0; i < numSamples; i++) {
    final attack  = i < attackSamples ? i / attackSamples : 1.0;
    final release = i > numSamples - releaseSamples
        ? (numSamples - i) / releaseSamples : 1.0;
    final t = i / sampleRate;
    final v = (sin(2 * pi * frequency * t) * attack * release * 28000)
        .round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, v, Endian.little);
  }

  return buf.buffer.asUint8List();
}

/// Noisy, out-of-tune fail sound: three detuned sawtooth-like oscillators
/// (300 / 317 / 337 Hz) that beat against each other harshly, mixed with
/// 15 % white noise, under a fast exponential-decay envelope (~600 ms).
Uint8List _buildFailSound() {
  const sampleRate = 44100;
  const durationMs = 650;
  final numSamples = (sampleRate * durationMs / 1000).round();
  final dataBytes  = numSamples * 2;
  final buf = ByteData(44 + dataBytes);
  final rng = Random();

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
  buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, 1, Endian.little);
  buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  buf.setUint32(40, dataBytes, Endian.little);

  // Three oscillators spaced to produce fast, clashing beats.
  // Each uses the first 5 harmonics (sawtooth approximation) for a buzzy timbre.
  const osc = [300.0, 317.0, 337.0];

  for (int i = 0; i < numSamples; i++) {
    final t   = i / sampleRate;
    final env = exp(-t * 7.5); // fast decay

    double s = 0;
    for (final f in osc) {
      // Sawtooth from odd harmonics (harsher than pure sine)
      for (int h = 1; h <= 5; h++) {
        s += sin(2 * pi * f * h * t) / h;
      }
    }
    s /= osc.length;

    // Mix in white noise (15 %)
    s = s * 0.85 + (rng.nextDouble() * 2 - 1) * 0.15;

    final v = (s * env * 22000).round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, v, Endian.little);
  }

  return buf.buffer.asUint8List();
}

Future<String> _writeTempWav(String name, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name.wav');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

// ── SoundPlayer ────────────────────────────────────────────────────────────

class SoundPlayer {
  // Single player for interactive combo sounds (one pitch at a time).
  final _comboPlayer  = AudioPlayer();
  // Separate player for the Promenade intro melody.
  final _melodyPlayer = AudioPlayer();
  // Dedicated player for the fail buzzer.
  final _failPlayer   = AudioPlayer();

  // Pre-written temp file paths, keyed by combo key string.
  final Map<String, String?> _comboPaths = {};
  String? _failPath;
  bool _ready = false;

  SoundPlayer() {
    _comboPlayer
      ..setReleaseMode(ReleaseMode.stop)
      ..setVolume(0.7);
    _melodyPlayer
      ..setReleaseMode(ReleaseMode.stop)
      ..setVolume(0.75);
    _failPlayer
      ..setReleaseMode(ReleaseMode.stop)
      ..setVolume(0.85);
    _init();
  }

  Future<void> _init() async {
    for (final entry in _kComboFreq.entries) {
      final bytes = _buildWav(entry.value, 1500);
      _comboPaths[entry.key] = await _writeTempWav('rb_${entry.key}', bytes);
    }
    _failPath = await _writeTempWav('rb_fail', _buildFailSound());
    _ready = true;
  }

  /// Play the single pitch assigned to [combo].
  Future<void> playCombo(Set<GameColor> combo) async {
    if (combo.isEmpty) return;
    final path = _comboPaths[_key(combo)];
    if (path == null) return; // still initialising
    await _comboPlayer.stop();
    await _comboPlayer.play(DeviceFileSource(path));
  }

  Future<void> stopCombo() => _comboPlayer.stop();

  /// Convenience alias used during sequence display.
  Future<void> playSet(Set<GameColor> colors) => playCombo(colors);

  Future<void> playFail() async {
    final path = _failPath;
    if (path == null) return;
    await _comboPlayer.stop(); // silence any held note first
    await _failPlayer.stop();
    await _failPlayer.play(DeviceFileSource(path));
  }

  Future<void> stopAll() async {
    await _comboPlayer.stop();
    await _melodyPlayer.stop();
    await _failPlayer.stop();
  }

  /// Play a melody note at [frequency] Hz (used by the Promenade intro).
  Future<void> playNote(double frequency, int durationMs) async {
    if (!_ready) return;
    final bytes = _buildWav(frequency, durationMs);
    final path  = await _writeTempWav('rb_melody', bytes);
    await _melodyPlayer.stop();
    await _melodyPlayer.play(DeviceFileSource(path));
  }

  Future<void> stopMelody() => _melodyPlayer.stop();

  void dispose() {
    _comboPlayer.dispose();
    _melodyPlayer.dispose();
    _failPlayer.dispose();
  }
}
