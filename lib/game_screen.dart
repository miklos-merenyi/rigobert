import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'circle_buttons.dart';
import 'game_colors.dart';
import 'sound_player.dart';

enum GamePhase { idle, showingSequence, playerInput, gameOverFlash, gameOver }

enum Difficulty { normal, floating, spinning, both }

// Opening melody – from intro.mid (Pictures at an Exhibition, 104 BPM).
// Each entry: (frequency_hz, duration_ms, button_highlight).
// Pitches:  F4=349.23 G4=392.00 Bb4=466.16 C5=523.25 D5=587.33 F5=698.46
// Buttons:  F→Red  G→Green  Bb→Blue  C→{R,G}  D→{R,B}  F'→{G,B}
// Phrase:   G  F  Bb  [C F']  D  [C F']  D  Bb  C  G  F
// Full beat = 550ms note + 10ms gap = 560ms ≈ 107 BPM (legato: 10ms silence).
// Half beat = 270ms note + 10ms gap; two halves = 560ms = one full beat.
const _introBpm     = 550; // ms – full beat note duration
const _introBpmHalf = 270; // ms – half beat (pickup); 2×(270+10)=560=1 beat
final _kPromenade = [
  (392.00, _introBpm,     <GameColor>{GameColor.green}),                    // G
  (349.23, _introBpm,     <GameColor>{GameColor.red}),                      // F
  (466.16, _introBpm,     <GameColor>{GameColor.blue}),                     // Bb
  (523.25, _introBpmHalf, <GameColor>{GameColor.red, GameColor.green}),     // C (half)
  (698.46, _introBpmHalf, <GameColor>{GameColor.green, GameColor.blue}),    // F' (half)
  (587.33, _introBpm,     <GameColor>{GameColor.red, GameColor.blue}),      // D
  (523.25, _introBpmHalf, <GameColor>{GameColor.red, GameColor.green}),     // C (half)
  (698.46, _introBpmHalf, <GameColor>{GameColor.green, GameColor.blue}),    // F' (half)
  (587.33, _introBpm,     <GameColor>{GameColor.red, GameColor.blue}),      // D
  (466.16, _introBpm,     <GameColor>{GameColor.blue}),                     // Bb
  (523.25, _introBpm,     <GameColor>{GameColor.red, GameColor.green}),     // C
  (392.00, _introBpm,     <GameColor>{GameColor.green}),                    // G
  (349.23, _introBpm,     <GameColor>{GameColor.red}),                      // F
];

const _allCombinations = [
  {GameColor.red},
  {GameColor.green},
  {GameColor.blue},
  {GameColor.red, GameColor.green},
  {GameColor.red, GameColor.blue},
  {GameColor.green, GameColor.blue},
  {GameColor.red, GameColor.green, GameColor.blue},
];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.idle;
  final List<Set<GameColor>> _sequence = [];
  int _playerStep = 0;
  Set<GameColor> _pressedButtons = {};
  Set<GameColor> _highlightedButtons = {}; // drives both display panel and circle buttons
  bool _stepMatched = false;
  bool _hasPressedThisStep = false;
  int _score = 0;
  int _personalRecord = 0;

  Color _displayColor = Colors.black;
  double _displayOpacity = 0.0;

  int _generation = 0;
  final _random = Random();
  final _sound = SoundPlayer();
  Difficulty _difficulty = Difficulty.normal;

  // Short chord-detection window: queues sound for the final combo only.
  Timer? _chordTimer;

  // Drives the time-remaining strip and also fires _gameOver on completion.
  late final AnimationController _timerCtrl;
  // Ticks at screen refresh rate — used only to drive AnimatedBuilder rebuilds.
  late final AnimationController _diffCtrl;
  // Monotonically increasing clock for smooth, wrap-free floating/spinning.
  final _floatClock = Stopwatch()..start();
  // Phase offsets corrected each time floatFreq/spinFreq changes with the level.
  double _floatPhaseX     = 0.0;
  double _floatPhaseY     = 0.0;
  double _spinPhaseOffset = 0.0;
  int    _floatLevel      = 0;

  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _gameOver();
    });
    _diffCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(); // runs continuously — never reset so position is always smooth
    _loadRecord();
    _runIntroLoop(_generation);
  }

  Future<void> _loadRecord() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _personalRecord = prefs.getInt('personal_record') ?? 0);
  }

  Future<void> _saveRecord(int score) async {
    if (score > _personalRecord) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('personal_record', score);
      setState(() => _personalRecord = score);
    }
  }

  Future<void> _runIntroLoop(int gen) async {
    await Future.delayed(const Duration(milliseconds: 600));
    while (mounted && _generation == gen && _phase == GamePhase.idle) {
      await _playIntro(gen);
      if (!mounted || _generation != gen) return;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _playIntro(int gen) async {
    for (final (freq, durMs, highlight) in _kPromenade) {
      if (!mounted || _generation != gen) return;
      setState(() {
        _highlightedButtons = Set.of(highlight);
        if (highlight.isNotEmpty) {
          _displayColor = mixColors(highlight);
          _displayOpacity = 0.55;
        } else {
          _displayOpacity = 0.0;
        }
      });
      if (freq > 0) _sound.playNote(freq, durMs);
      await Future.delayed(Duration(milliseconds: durMs));
      if (!mounted || _generation != gen) return;
      setState(() {
        _highlightedButtons = {};
        _displayOpacity = 0.0;
      });
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  void _startInputTimer() {
    _timerCtrl.stop();
    _timerCtrl.value = 0.0;
    _timerCtrl.forward();
  }

  void _cancelInputTimer() {
    _timerCtrl.stop();
    _timerCtrl.value = 0.0;
    _chordTimer?.cancel();
    _chordTimer = null;
  }

  @override
  void dispose() {
    _chordTimer?.cancel();
    _timerCtrl.dispose();
    _diffCtrl.dispose();
    _sound.dispose();
    super.dispose();
  }

  void _goToIdle() {
    _cancelInputTimer();
    _sound.stopAll();
    _generation++;
    setState(() {
      _phase = GamePhase.idle;
      _sequence.clear();
      _score = 0;
      _pressedButtons = {};
      _highlightedButtons = {};
      _stepMatched = false;
      _hasPressedThisStep = false;
      _displayOpacity = 0.0;
      _floatPhaseX = 0.0;
      _floatPhaseY = 0.0;
      _spinPhaseOffset = 0.0;
      _floatLevel = 0;
    });
    _runIntroLoop(_generation);
  }

  void _startGame() {
    _cancelInputTimer();
    _sound.stopMelody();
    _generation++;
    setState(() {
      _sequence.clear();
      _score = 0;
      _pressedButtons = {};
      _highlightedButtons = {};
      _stepMatched = false;
      _hasPressedThisStep = false;
      _displayOpacity = 0.0;
      _floatPhaseX = 0.0;
      _floatPhaseY = 0.0;
      _spinPhaseOffset = 0.0;
      _floatLevel = 0;
    });
    _addNextStep();
  }

  // Called after _sequence.length changes so position formulas stay continuous.
  void _updateFloatPhase() {
    final secs     = _floatClock.elapsed.inMilliseconds / 1000.0;
    final newLevel = _sequence.length;
    if (newLevel == _floatLevel) return;
    final oldFloat = 0.04 + _floatLevel * 0.012;
    final newFloat = 0.04 + newLevel   * 0.012;
    _floatPhaseX += (oldFloat - newFloat) * secs * 2 * pi;
    _floatPhaseY += (oldFloat - newFloat) * secs * 1.4 * 2 * pi;
    final oldSpin = 0.10 + _floatLevel * 0.025;
    final newSpin = 0.10 + newLevel   * 0.025;
    _spinPhaseOffset += (oldSpin - newSpin) * secs * 2 * pi;
    _floatLevel = newLevel;
  }

  void _addNextStep() {
    _sequence.add(
      Set.of(_allCombinations[_random.nextInt(_allCombinations.length)]),
    );
    _updateFloatPhase();
    _showSequence(_generation);
  }

  Future<void> _showSequence(int gen) async {
    if (!mounted || _generation != gen) return;
    setState(() => _phase = GamePhase.showingSequence);
    await Future.delayed(const Duration(milliseconds: 600));

    for (int i = 0; i < _sequence.length; i++) {
      final step = _sequence[i];
      final isLast = i == _sequence.length - 1;
      if (!mounted || _generation != gen) return;
      setState(() {
        _displayColor = mixColors(step);
        _displayOpacity = 1.0;
        _highlightedButtons = Set.of(step);
      });
      _sound.playSet(step);

      if (isLast) {
        // Enable input the moment the last note begins.
        if (!mounted || _generation != gen) return;
        setState(() {
          _phase = GamePhase.playerInput;
          _playerStep = 0;
          _hasPressedThisStep = false;
          _stepMatched = false;
          _highlightedButtons = {};
          _displayOpacity = 0.0;
        });
        _startInputTimer();
        return;
      }

      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted || _generation != gen) return;
      _sound.stopAll();
      setState(() {
        _displayOpacity = 0.0;
        _highlightedButtons = {};
      });
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  void _onButtonDown(GameColor color) {
    if (_phase != GamePhase.playerInput) return;
    _startInputTimer();
    final newPressed = Set<GameColor>.from(_pressedButtons)..add(color);
    _handlePressChange(newPressed);

    // Chord window: restart the timer on every new press.  When it fires
    // we play exactly the combo that is held at that moment, so two fingers
    // landing within 40 ms produce only one (combo) sound, not two.
    // If all fingers lifted before the window expires, fall back to the
    // snapshot captured at this down-event.
    final snapshot = Set.of(newPressed);
    _chordTimer?.cancel();
    _chordTimer = Timer(const Duration(milliseconds: 40), () {
      _sound.playCombo(_pressedButtons.isNotEmpty ? _pressedButtons : snapshot);
    });
  }

  void _onButtonUp(GameColor color) {
    if (_phase != GamePhase.playerInput) return;
    final newPressed = Set<GameColor>.from(_pressedButtons)..remove(color);
    // No sound on release — only down-events queue notes.
    // The current note rings out naturally.
    _handlePressChange(newPressed);
  }

  void _handlePressChange(Set<GameColor> pressed) {
    if (_stepMatched) {
      setState(() {
        _pressedButtons = pressed;
        _highlightedButtons = Set.of(pressed);
      });
      if (pressed.isEmpty) _advanceStep();
      return;
    }

    if (pressed.isNotEmpty) _hasPressedThisStep = true;

    setState(() {
      _pressedButtons = pressed;
      _highlightedButtons = Set.of(pressed);
      _displayColor = pressed.isEmpty ? Colors.black : mixColors(pressed);
      _displayOpacity = pressed.isEmpty ? 0.0 : 0.5;
    });

    final required = _sequence[_playerStep];
    if (setEquals(pressed, required)) {
      _cancelInputTimer(); // step matched — no timeout needed while releasing
      setState(() {
        _stepMatched = true;
        _displayOpacity = 1.0;
        _score++;
      });
      return;
    }

    if (pressed.isEmpty && _hasPressedThisStep) {
      _gameOver();
    }
  }

  void _advanceStep() {
    setState(() {
      _stepMatched = false;
      _hasPressedThisStep = false;
      _displayColor = Colors.black;
      _displayOpacity = 0.0;
      _highlightedButtons = {};
      _playerStep++;
    });
    if (_playerStep >= _sequence.length) {
      Future.delayed(const Duration(milliseconds: 500), _addNextStep);
    } else {
      _startInputTimer(); // fresh 5s for the next step
    }
  }

  void _gameOver() {
    _cancelInputTimer();
    _sound.playFail();
    _saveRecord(_score);
    setState(() {
      _phase = GamePhase.gameOverFlash;
      _highlightedButtons = {};
      _displayOpacity = 0.0;
    });
    _runGameOverFlash(_generation);
  }

  Future<void> _runGameOverFlash(int gen) async {
    final deadline = DateTime.now().add(const Duration(milliseconds: 2400));
    while (mounted && _generation == gen && DateTime.now().isBefore(deadline)) {
      final combo = Set.of(_allCombinations[_random.nextInt(_allCombinations.length)]);
      setState(() {
        _highlightedButtons = combo;
        _displayColor = mixColors(combo);
        _displayOpacity = 0.75;
      });
      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted || _generation != gen) return;
      setState(() {
        _highlightedButtons = {};
        _displayOpacity = 0.0;
      });
      await Future.delayed(const Duration(milliseconds: 90));
    }
    if (!mounted || _generation != gen) return;
    setState(() => _phase = GamePhase.gameOver);
  }

  bool get _buttonsEnabled => _phase == GamePhase.playerInput;
  bool get _isFloating =>
      _difficulty == Difficulty.floating || _difficulty == Difficulty.both;
  bool get _isSpinning =>
      _difficulty == Difficulty.spinning || _difficulty == Difficulty.both;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    _buildDisplay(),
                    _buildStatusRow(),
                    _buildButtons(),
                    _buildLevelDots(),
                    _buildTimerStrip(),
                  ],
                ),
                if (_isFloating) _buildFloatingDisc(constraints),
                if (_phase == GamePhase.idle) _buildOverlay(isGameOver: false),
                if (_phase == GamePhase.gameOver) _buildOverlay(isGameOver: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const base = TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4);
    // R=red, U=orange, G=green, B=blue, A=yellow, R=red, T=purple · S=cyan, A=yellow, Y=magenta, S=cyan
    final letters = [
      ('R', const Color(0xFFFF3333)),
      ('U', Colors.orange),
      ('G', const Color(0xFF33FF33)),
      ('B', const Color(0xFF3366FF)),
      ('A', Colors.yellow),
      ('R', const Color(0xFFFF3333)),
      ('T', Colors.purpleAccent),
      (' ', Colors.white),
      ('S', const Color(0xFF00FFFF)),
      ('A', Colors.yellow),
      ('Y', const Color(0xFFFF00FF)),
      ('S', const Color(0xFF00FFFF)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: RichText(
        text: TextSpan(
          children: [
            for (final (char, color) in letters)
              TextSpan(text: char, style: base.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplay() {
    return Expanded(
      flex: 4,
      child: Center(
        child: AnimatedOpacity(
          opacity: _displayOpacity,
          duration: const Duration(milliseconds: 180),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: _displayColor,
              shape: BoxShape.circle,
              boxShadow: _displayOpacity > 0.05
                  ? [
                      BoxShadow(
                        color: _displayColor.withValues(alpha: 0.65),
                        blurRadius: 60,
                        spreadRadius: 15,
                      )
                    ]
                  : [],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    String status;
    switch (_phase) {
      case GamePhase.showingSequence:
        status = 'Watch carefully…';
      case GamePhase.playerInput:
        status = 'Step ${_playerStep + 1} / ${_sequence.length}';
      case GamePhase.gameOverFlash:
        status = '';
      default:
        status = '';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(
            'Level ${_sequence.length}   •   Score $_score',
            style: const TextStyle(fontSize: 17, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: const TextStyle(fontSize: 13, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    // When floating the disc lives in the root Stack via _buildFloatingDisc().
    if (_isFloating) {
      return const Expanded(flex: 4, child: SizedBox());
    }

    final disc = CircleButtons(
      highlighted: _highlightedButtons,
      enabled: _buttonsEnabled,
      onDown: _onButtonDown,
      onUp: _onButtonUp,
    );

    return Expanded(
      flex: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: _isSpinning
            ? AnimatedBuilder(
                animation: _diffCtrl,
                builder: (context, child) {
                  final secs = _floatClock.elapsed.inMilliseconds / 1000.0;
                  final freq = 0.10 + _sequence.length * 0.025;
                  return Transform.rotate(
                    angle: secs * freq * 2 * pi + _spinPhaseOffset,
                    child: child,
                  );
                },
                child: disc,
              )
            : disc,
      ),
    );
  }

  Widget _buildFloatingDisc(BoxConstraints constraints) {
    final sw = constraints.maxWidth;
    final sh = constraints.maxHeight;
    final discSize = min(sw * 0.72, sh * 0.45);
    final hRange = (sw - discSize) / 2 - 16;
    final vRange = (sh - discSize) / 2 - 16;

    final disc = CircleButtons(
      highlighted: _highlightedButtons,
      enabled: _buttonsEnabled,
      onDown: _onButtonDown,
      onUp: _onButtonUp,
    );

    return AnimatedBuilder(
      animation: _diffCtrl,
      builder: (context, child) {
        // Use monotonic elapsed seconds so position is always continuous —
        // no jump when the controller loops 0→1→0.
        final secs = _floatClock.elapsed.inMilliseconds / 1000.0;
        // Float frequency grows with level: 25-second cycle at level 0,
        // shortening by ~0.8 s per additional level.
        final floatFreq = 0.04 + _sequence.length * 0.012;
        final dx = sin(secs * floatFreq * 2 * pi + _floatPhaseX) * hRange;
        final dy = sin(secs * floatFreq * 1.4 * 2 * pi + pi / 3 + _floatPhaseY) * vRange;

        Widget w = child!;
        if (_isSpinning) {
          final spinFreq = 0.10 + _sequence.length * 0.025;
          w = Transform.rotate(angle: secs * spinFreq * 2 * pi + _spinPhaseOffset, child: w);
        }
        return Positioned(
          left: sw / 2 + dx - discSize / 2,
          top:  sh / 2 + dy - discSize / 2,
          width: discSize,
          height: discSize,
          child: w,
        );
      },
      child: disc,
    );
  }

  Widget _buildOverlay({required bool isGameOver}) {
    final title = isGameOver ? 'Game Over' : 'Rugbart Says';
    final isNewRecord = isGameOver && _score > 0 && _score >= _personalRecord;
    final scoreLines = isGameOver
        ? 'You reached level ${_sequence.length}\nScore: $_score'
            '${isNewRecord ? '\n🏆 New Record!' : (_personalRecord > 0 ? '\nRecord: $_personalRecord' : '')}'
        : 'Watch the flashing colours,\nthen repeat — even two or three\nbuttons at the same time!';
    final subtitle = scoreLines;
    final buttonLabel = isGameOver ? 'TRY AGAIN' : 'START';

    final innerContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white60,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              if (!isGameOver) _buildIntroLights(),
              const SizedBox(height: 20),
              if (!isGameOver) _buildDifficultySelector(),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: isGameOver ? _goToIdle : _startGame,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              if (isGameOver) ...[
                const SizedBox(height: 24),
                _buildColorLegend(),
              ],
            ],
          ),
        );

    if (isGameOver) {
      return Container(color: Colors.black87, child: Center(child: innerContent));
    }

    // Idle: fade to transparent so the button disc is visible at the bottom.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.52, 0.80],
          colors: [
            Color(0xF2000000),
            Color(0xE0000000),
            Colors.transparent,
          ],
        ),
      ),
      child: Align(
        alignment: Alignment(0, -0.35),
        child: innerContent,
      ),
    );
  }

  Widget _buildIntroLights() {
    const dotColors = {
      GameColor.red:   Color(0xFFFF3333),
      GameColor.green: Color(0xFF33FF33),
      GameColor.blue:  Color(0xFF3366FF),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: GameColor.values.map((color) {
        final base = dotColors[color]!;
        final isLit = _highlightedButtons.contains(color);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLit ? base : base.withValues(alpha: 0.15),
            boxShadow: isLit
                ? [BoxShadow(color: base.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 4)]
                : [],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLevelDots() {
    final count = _sequence.length;
    if (count == 0) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 4,
        children: List.generate(
          count,
          (_) => Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white54,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerStrip() {
    return AnimatedBuilder(
      animation: _timerCtrl,
      builder: (context, _) {
        if (_phase != GamePhase.playerInput) return const SizedBox(height: 6);
        final remaining = (1.0 - _timerCtrl.value).clamp(0.0, 1.0);
        final color = Color.lerp(Colors.red, Colors.green, remaining)!;
        return SizedBox(
          height: 6,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: remaining,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.7),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDifficultySelector() {
    const options = [
      (Difficulty.floating, 'FLOAT'),
      (Difficulty.spinning, 'SPIN'),
      (Difficulty.both,     'BOTH'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: options.map((opt) {
        final (diff, label) = opt;
        final selected = _difficulty == diff;
        return GestureDetector(
          onTap: () => setState(
              () => _difficulty = selected ? Difficulty.normal : diff),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? Colors.white70 : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorLegend() {
    final combos = [
      ({GameColor.red, GameColor.green}, 'Red + Green = Yellow'),
      ({GameColor.red, GameColor.blue}, 'Red + Blue = Magenta'),
      ({GameColor.green, GameColor.blue}, 'Green + Blue = Cyan'),
      ({GameColor.red, GameColor.green, GameColor.blue}, 'All three = White'),
    ];
    return Column(
      children: combos.map((entry) {
        final (combo, label) = entry;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: mixColors(combo),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
