import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'circle_buttons.dart';
import 'game_colors.dart';
import 'sound_player.dart';

enum GamePhase { idle, showingSequence, playerInput, gameOverFlash, gameOver }

enum Difficulty { normal, floating, spinning, both }

// Pictures at an Exhibition – Promenade theme (A major transposition).
// Each entry: (frequency_hz, duration_ms, button_highlight).
// Melody pitches: A=440, B=494, C#=554, D=587, E=659.
// Button mappings: A→Red, B→{R,G}, C#→Green, D→{G,B}, E→Blue.
const _introBpm = 360; // ms per quarter note
final _kPromenade = [
  (440.0, _introBpm,     <GameColor>{GameColor.red}),
  (440.0, _introBpm,     <GameColor>{GameColor.red}),
  (440.0, _introBpm,     <GameColor>{GameColor.red}),
  (440.0, _introBpm,     <GameColor>{GameColor.red}),
  (440.0, _introBpm,     <GameColor>{GameColor.red}),
  (494.0, _introBpm,     <GameColor>{GameColor.red, GameColor.green}),
  (554.0, _introBpm,     <GameColor>{GameColor.green}),
  (440.0, _introBpm * 2, <GameColor>{GameColor.red}),
  (0.0,   200,           <GameColor>{}),
  (554.0, _introBpm,     <GameColor>{GameColor.green}),
  (494.0, _introBpm,     <GameColor>{GameColor.red, GameColor.green}),
  (440.0, _introBpm,     <GameColor>{GameColor.red}),
  (554.0, _introBpm,     <GameColor>{GameColor.green}),
  (587.0, _introBpm,     <GameColor>{GameColor.green, GameColor.blue}),
  (554.0, _introBpm,     <GameColor>{GameColor.green}),
  (494.0, _introBpm,     <GameColor>{GameColor.red, GameColor.green}),
  (440.0, _introBpm * 2, <GameColor>{GameColor.red}),
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

  // Drives the time-remaining strip and also fires _gameOver on completion.
  late final AnimationController _timerCtrl;
  // Drives disc floating / spinning during gameplay.
  late final AnimationController _diffCtrl;

  static const _windowChannel = MethodChannel('com.rugbart/window');
  bool _secureActive = false;

  Future<void> _setSecure(bool secure) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (secure == _secureActive) return;
    _secureActive = secure;
    try {
      await _windowChannel.invokeMethod<void>('setSecure', {'secure': secure});
    } catch (_) {}
  }

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
      await Future.delayed(const Duration(milliseconds: 80));
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
  }

  @override
  void dispose() {
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
    });
    _addNextStep();
  }

  void _addNextStep() {
    _sequence.add(
      Set.of(_allCombinations[_random.nextInt(_allCombinations.length)]),
    );
    _showSequence(_generation);
  }

  Future<void> _showSequence(int gen) async {
    if (!mounted || _generation != gen) return;
    setState(() => _phase = GamePhase.showingSequence);
    await Future.delayed(const Duration(milliseconds: 600));

    for (final step in _sequence) {
      if (!mounted || _generation != gen) return;
      // Light up both display panel and circle buttons
      setState(() {
        _displayColor = mixColors(step);
        _displayOpacity = 1.0;
        _highlightedButtons = Set.of(step);
      });
      _sound.playSet(step);
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted || _generation != gen) return;
      _sound.stopAll();
      setState(() {
        _displayOpacity = 0.0;
        _highlightedButtons = {};
      });
      await Future.delayed(const Duration(milliseconds: 350));
    }

    if (!mounted || _generation != gen) return;
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _phase = GamePhase.playerInput;
      _playerStep = 0;
      _hasPressedThisStep = false;
      _stepMatched = false;
    });
    _startInputTimer();
  }

  void _onButtonDown(GameColor color) {
    if (_phase != GamePhase.playerInput) return;
    _startInputTimer();
    final newPressed = Set<GameColor>.from(_pressedButtons)..add(color);
    _sound.playCombo(newPressed);
    _handlePressChange(newPressed);
  }

  void _onButtonUp(GameColor color) {
    if (_phase != GamePhase.playerInput) return;
    final newPressed = Set<GameColor>.from(_pressedButtons)..remove(color);
    if (newPressed.isEmpty) {
      _sound.stopCombo();
    } else {
      _sound.playCombo(newPressed);
    }
    _handlePressChange(newPressed);
  }

  void _handlePressChange(Set<GameColor> pressed) {
    // Prevent accidental 3-finger screenshots on Android when all buttons held
    _setSecure(pressed.length == GameColor.values.length);

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
    _setSecure(false);
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
                  return Transform.rotate(
                    angle: _diffCtrl.value * 2 * pi,
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
        final t = _diffCtrl.value;
        final dx = sin(t * 2 * pi) * hRange;
        final dy = sin(t * 2 * pi * 1.4 + pi / 3) * vRange;
        final cx = sw / 2 + dx;
        final cy = sh / 2 + dy;

        Widget w = child!;
        if (_isSpinning) {
          w = Transform.rotate(angle: t * 2 * pi, child: w);
        }
        return Positioned(
          left: cx - discSize / 2,
          top: cy - discSize / 2,
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

    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
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
        ),
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
