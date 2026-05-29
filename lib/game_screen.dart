import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'circle_buttons.dart';
import 'game_colors.dart';
import 'leaderboard_service.dart';
import 'purchase_service.dart';
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
  bool _recordSubmitted = false;
  // Per-mode personal records keyed by Difficulty
  final Map<Difficulty, int> _records = {
    Difficulty.normal:   0,
    Difficulty.floating: 0,
    Difficulty.spinning: 0,
    Difficulty.both:     0,
  };

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
  // Intro plays exactly once at startup; after it finishes buttons become an instrument.
  bool _introPlaying    = false;
  bool _hasPlayedIntro  = false;
  bool _isNewRecord     = false;
  Difficulty _gameOverDifficulty = Difficulty.normal;

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
    LeaderboardService().silentSignIn();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowScreenshotTip());
    }
  }

  Future<void> _maybeShowScreenshotTip() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('screenshot_tip_shown') ?? false) return;
    await prefs.setBool('screenshot_tip_shown', true);
    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 2)); // let intro settle
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡  Tip', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: Colors.white38, letterSpacing: 2,
            )),
            const SizedBox(height: 12),
            const Text(
              'Some Android devices take a screenshot when you swipe with three fingers — which can accidentally interrupt the game.',
              style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.6),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can disable this in Settings → Advanced features → Motions and gestures → Palm swipe to capture (or similar, depending on your device).',
              style: TextStyle(fontSize: 13, color: Colors.white38, height: 1.6),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Center(
                  child: Text('Got it', style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _recordKey(Difficulty d) => 'record_${d.name}';

  Future<void> _loadRecord() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final d in Difficulty.values) {
        _records[d] = prefs.getInt(_recordKey(d)) ?? 0;
      }
    });
  }

  /// Saves a new record if [score] beats the current one for [diff].
  /// Returns (isNewRecord, wasSubmittedToLeaderboard).
  Future<(bool, bool)> _saveRecord(int score, Difficulty diff) async {
    if (score > (_records[diff] ?? 0)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_recordKey(diff), score);
      setState(() => _records[diff] = score);
      final submitted = await LeaderboardService()
          .submitScore(_difficultyName(diff).toLowerCase(), score);
      return (true, submitted);
    }
    return (false, false);
  }

  Future<void> _runIntroLoop(int gen) async {
    if (_hasPlayedIntro) return; // subsequent idle visits → instrument mode immediately
    _hasPlayedIntro = true;
    setState(() => _introPlaying = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _generation != gen) {
      if (mounted) setState(() => _introPlaying = false);
      return;
    }
    await _playIntro(gen);
    if (mounted) setState(() => _introPlaying = false);
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

  // ── Tip jar & leaderboard ─────────────────────────────────────────────────

  Future<void> _openTipJar() => showTipJar(context);

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListenableBuilder(
        listenable: LeaderboardService(),
        builder: (ctx, __) {
          final lb = LeaderboardService();
          return Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SETTINGS', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: Colors.white38, letterSpacing: 3,
                )),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Leaderboard',
                              style: TextStyle(fontSize: 15, color: Colors.white70,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 3),
                          Text('Submit personal records to the global leaderboard',
                              style: TextStyle(fontSize: 12, color: Colors.white38, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => lb.setOptedOut(!lb.optedOut),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: lb.optedOut
                              ? Colors.white12
                              : const Color(0xFF44DD88).withValues(alpha: 0.35),
                          border: Border.all(
                            color: lb.optedOut
                                ? Colors.white24
                                : const Color(0xFF44DD88),
                            width: 1.2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              left: lb.optedOut ? 2 : 20,
                              top: 2,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: lb.optedOut
                                      ? Colors.white38
                                      : const Color(0xFF44DD88),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openLeaderboard() async {
    final lb = LeaderboardService();
    if (!lb.isSignedIn) {
      // Politely ask before trying interactive sign-in.
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Sign in?',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          content: const Text(
            'Leaderboards are powered by Game Center (iOS) or Play Games (Android). '
            'Sign in to view rankings — or skip if you\'d rather not.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign in', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      final ok = await lb.interactiveSignIn();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not sign in — try again later.'),
            backgroundColor: Color(0xFF2A2A3A),
          ));
        }
        return;
      }
    }
    await lb.showLeaderboard(_difficultyName(_gameOverDifficulty).toLowerCase());
  }

  Future<void> _startGame() async {
    _cancelInputTimer();
    _sound.stopMelody();
    _generation++;
    final gen = _generation;
    setState(() {
      _phase = GamePhase.showingSequence; // hide overlay immediately on tap
      _sequence.clear();
      _score = 0;
      _pressedButtons = {};
      _highlightedButtons = {};
      _stepMatched = false;
      _hasPressedThisStep = false;
      _displayOpacity = 0.0;
      _floatPhaseX = 0.0;
      // BOTH mode: start from bottom (sin(pi/3 + pi/6) = sin(pi/2) = 1 → dy = vRange)
      _floatPhaseY = _difficulty == Difficulty.both ? pi / 6 : 0.0;
      _spinPhaseOffset = 0.0;
      _floatLevel = 0;
    });
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted || _generation != gen) return;
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
        // Enable input the moment the last note begins (highlight is already
        // set from the setState above so the player sees it light up).
        if (!mounted || _generation != gen) return;
        setState(() {
          _phase = GamePhase.playerInput;
          _playerStep = 0;
          _hasPressedThisStep = false;
          _stepMatched = false;
        });
        _startInputTimer();
        // Clear the last-note highlight after a short visual window, but only
        // if the player hasn't already started pressing (their press takes over).
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _generation != gen) return;
          if (_pressedButtons.isEmpty) {
            setState(() {
              _highlightedButtons = {};
              _displayOpacity = 0.0;
            });
          }
        });
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

  // Instrument mode: press buttons freely on the idle screen.
  void _playIdleNote(GameColor color) {
    final newPressed = Set<GameColor>.from(_pressedButtons)..add(color);
    setState(() {
      _pressedButtons = newPressed;
      _highlightedButtons = Set.of(newPressed);
      _displayColor = mixColors(newPressed);
      _displayOpacity = 0.5;
    });
    // Cancel any pending timer AND stop whatever sound already started,
    // so a second finger arriving after the window doesn't overlap.
    _chordTimer?.cancel();
    _sound.stopCombo();
    final snapshot = Set.of(newPressed);
    _chordTimer = Timer(const Duration(milliseconds: 80), () {
      _sound.playCombo(_pressedButtons.isNotEmpty ? _pressedButtons : snapshot);
    });
  }

  void _onButtonDown(GameColor color) {
    if (_phase == GamePhase.idle) { _playIdleNote(color); return; }
    if (_phase != GamePhase.playerInput) return;
    _startInputTimer();
    final newPressed = Set<GameColor>.from(_pressedButtons)..add(color);
    _handlePressChange(newPressed);

    // Chord window: on every new press, cancel the pending timer AND stop any
    // sound that already fired from a previous press in this gesture.
    // This ensures the sound only plays once the full chord is known.
    _chordTimer?.cancel();
    _sound.stopCombo();
    final snapshot = Set.of(newPressed);
    _chordTimer = Timer(const Duration(milliseconds: 80), () {
      _sound.playCombo(_pressedButtons.isNotEmpty ? _pressedButtons : snapshot);
    });
  }

  void _onButtonUp(GameColor color) {
    if (_phase == GamePhase.idle) {
      final newPressed = Set<GameColor>.from(_pressedButtons)..remove(color);
      setState(() {
        _pressedButtons = newPressed;
        _highlightedButtons = Set.of(newPressed);
        if (newPressed.isEmpty) _displayOpacity = 0.0;
      });
      return;
    }
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

    // If any pressed button is not in the required set, it's immediately wrong.
    // Don't wait for release — this prevents a wrong+right chord from slipping
    // through when the wrong finger lifts before the check runs.
    if (pressed.isNotEmpty && !required.containsAll(pressed)) {
      _gameOver();
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
    final diffAtGameOver = _difficulty;
    _saveRecord(_score, diffAtGameOver).then((result) {
      final (wasNew, submitted) = result;
      if (mounted) setState(() {
        _isNewRecord = wasNew;
        _recordSubmitted = submitted;
        _gameOverDifficulty = diffAtGameOver;
      });
    });
    setState(() {
      _phase = GamePhase.gameOverFlash;
      _highlightedButtons = {};
      _displayOpacity = 0.0;
      _isNewRecord = false;
      _gameOverDifficulty = diffAtGameOver;
    });
    _runGameOverFlash(_generation);
    // Count rounds and maybe show tip prompt after the flash.
    PurchaseService().incrementRounds().then((_) {
      if (!mounted) return;
      if (PurchaseService().shouldShowTipPrompt) {
        Future.delayed(const Duration(milliseconds: 2600), () {
          if (mounted) showTipJar(context);
        });
      }
    });
  }

  Future<void> _runGameOverFlash(int gen) async {
    final deadline = DateTime.now().add(const Duration(milliseconds: 2400));
    while (mounted && _generation == gen && DateTime.now().isBefore(deadline)) {
      final combo = Set.of(_allCombinations[_random.nextInt(_allCombinations.length)]);
      _sound.playR2D2Beep();
      setState(() {
        _highlightedButtons = combo;
        _displayColor = mixColors(combo);
        _displayOpacity = 0.75;
      });
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted || _generation != gen) return;
      setState(() {
        _highlightedButtons = {};
        _displayOpacity = 0.0;
      });
      await Future.delayed(const Duration(milliseconds: 60));
    }
    if (!mounted || _generation != gen) return;
    setState(() => _phase = GamePhase.gameOver);
    // Show record congratulations after a short beat.
    if (_isNewRecord) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted && _generation == gen) _showRecordCongrats();
    }
  }

  Future<void> _showRecordCongrats() async {
    final score      = _score;
    final modeName   = _difficultyName(_gameOverDifficulty);
    final submitted  = _recordSubmitted;
    final lb         = LeaderboardService();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => _RecordCongratsDialog(
        score: score,
        modeName: modeName,
        submitted: submitted,
        leaderboardService: lb,
      ),
    );
  }

  bool get _buttonsEnabled =>
      _phase == GamePhase.playerInput ||
      (_phase == GamePhase.idle && !_introPlaying);
  bool get _isFloating =>
      _difficulty == Difficulty.floating || _difficulty == Difficulty.both;
  bool get _isSpinning =>
      _difficulty == Difficulty.spinning || _difficulty == Difficulty.both;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF33334A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_phase == GamePhase.idle) {
              return _buildIdleScreen(constraints);
            }
            return Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    _buildDisplay(),
                    _buildStatusRow(),
                    _buildButtons(constraints),
                    _buildLevelDots(),
                    _buildTimerStrip(),
                  ],
                ),
                if (_isFloating) _buildFloatingDisc(constraints),
                if (_phase == GamePhase.gameOver) _buildOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIdleScreen(BoxConstraints constraints) {
    final sw = constraints.maxWidth;
    final sh = constraints.maxHeight;
    final discSize = min(sw * 0.72, sh * 0.45);

    // Disc widget — same as gameplay
    Widget discWidget = CircleButtons(
      highlighted: _highlightedButtons,
      enabled: _buttonsEnabled,
      onDown: _onButtonDown,
      onUp: _onButtonUp,
    );
    if (_isSpinning) {
      discWidget = AnimatedBuilder(
        animation: _diffCtrl,
        builder: (context, child) {
          final secs = _floatClock.elapsed.inMilliseconds / 1000.0;
          return Transform.rotate(
            angle: secs * 0.10 * 2 * pi + _spinPhaseOffset,
            child: child!,
          );
        },
        child: discWidget,
      );
    }

    // Centred disc position (used when not floating)
    final discTop = sh * 0.24;

    // Personal record for the currently selected mode
    final modeRecord = _records[_difficulty] ?? 0;
    final modeName   = _difficultyName(_difficulty);

    return Stack(
      children: [
        // ── disc ─────────────────────────────────────────────────────────────
        if (_isFloating)
          _buildFloatingDisc(constraints)
        else
          Positioned(
            left: (sw - discSize) / 2,
            top: discTop,
            width: discSize,
            height: discSize,
            child: discWidget,
          ),

        // ── title — centred vertically in the upper half ──────────────────
        Positioned(
          top: sh * 0.08,
          left: 16, right: 16,
          child: Center(child: _buildIdleTitle()),
        ),

        // ── bottom controls ───────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.65, 1.0],
                colors: [
                  const Color(0xFF33334A),
                  const Color(0xDD33334A),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIntroLights(),
                const SizedBox(height: 16),
                _buildDifficultySelector(),
                const SizedBox(height: 8),
                // Personal record for chosen mode
                if (modeRecord > 0)
                  Text(
                    '$modeName mode record: $modeRecord',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                      letterSpacing: 0.5,
                    ),
                  ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _startGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: const Text(
                      'START',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HowToPlayPage()),
                      ),
                      child: const Text(
                        'How to play',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white38,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white24,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () => _openSettings(context),
                      child: const Icon(Icons.settings_outlined,
                          size: 18, color: Colors.white24),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Compact header used during gameplay (top of screen)
  Widget _buildHeader() {
    final base = GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4);
    final letters = [
      ('R', const Color(0xFFFF3333)),
      ('I', Colors.orange),
      ('G', const Color(0xFF33FF33)),
      ('O', Colors.yellow),
      ('B', const Color(0xFF3366FF)),
      ('E', Colors.purpleAccent),
      ('R', const Color(0xFFFF3333)),
      ('T', Colors.white),
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

  // Large skewed title for the opening/idle screen
  Widget _buildIdleTitle() {
    final base = GoogleFonts.nunito(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 3);
    const letters = [
      ('R', Color(0xFFFF3333),   0.18),
      ('I', Colors.orange,      -0.22),
      ('G', Color(0xFF33FF33),   0.14),
      ('O', Colors.yellow,       0.25),
      ('B', Color(0xFF3366FF),  -0.16),
      ('E', Colors.purpleAccent, 0.20),
      ('R', Color(0xFFFF3333),  -0.12),
      ('T', Colors.white,        0.23),
      (' ', Colors.white,        0.00),
      ('S', Color(0xFF00FFFF),  -0.19),
      ('A', Colors.yellow,       0.15),
      ('Y', Color(0xFFFF00FF),  -0.24),
      ('S', Color(0xFF00FFFF),   0.13),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final (char, color, angle) in letters)
            Transform.rotate(
              angle: angle,
              child: Text(char, style: base.copyWith(color: color)),
            ),
        ],
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

  Widget _buildButtons(BoxConstraints screenConstraints) {
    // When floating the disc lives in the root Stack via _buildFloatingDisc().
    if (_isFloating) {
      return const Expanded(flex: 4, child: SizedBox());
    }

    // Use the same size formula as _buildFloatingDisc so STILL/SPIN match
    // FLOAT/BOTH exactly.
    final discSize = min(screenConstraints.maxWidth * 0.72,
                        screenConstraints.maxHeight * 0.45);

    final disc = CircleButtons(
      highlighted: _highlightedButtons,
      enabled: _buttonsEnabled,
      onDown: _onButtonDown,
      onUp: _onButtonUp,
    );

    Widget discWidget = _isSpinning
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
        : disc;

    return Expanded(
      flex: 4,
      child: Center(
        child: SizedBox(
          width: discSize,
          height: discSize,
          child: discWidget,
        ),
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

  Widget _buildGameOverTitle() {
    final style = GoogleFonts.nunito(fontSize: 46, fontWeight: FontWeight.w900);
    const letters = [
      ('G', Color(0xFFFF3333),   0.09),
      ('A', Colors.orange,      -0.07),
      ('M', Color(0xFFFF6600),   0.00),
      ('E', Colors.yellow,      -0.11),
      (' ', Colors.white,        0.00),
      ('O', Color(0xFFFF3333),   0.08),
      ('V', Colors.purpleAccent,-0.09),
      ('E', Colors.orange,       0.12),
      ('R', Color(0xFFFF4444),  -0.06),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final (char, color, angle) in letters)
            Transform.rotate(
              angle: angle,
              child: Text(char, style: style.copyWith(color: color)),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlayTitle() {
    final style = GoogleFonts.nunito(fontSize: 44, fontWeight: FontWeight.w900);
    const letters = [
      ('R', Color(0xFFFF3333),   0.00),
      ('I', Colors.orange,      -0.10),
      ('G', Color(0xFF33FF44),   0.00),
      ('O', Colors.yellow,       0.13),
      ('B', Color(0xFF3366FF),  -0.08),
      ('E', Colors.purpleAccent, 0.00),
      ('R', Color(0xFFFF3333),   0.11),
      ('T', Colors.white,       -0.06),
      (' ', Colors.white,        0.00),
      ('S', Color(0xFF00FFFF),  -0.12),
      ('A', Colors.yellow,       0.00),
      ('Y', Color(0xFFFF00FF),   0.09),
      ('S', Color(0xFF00FFFF),  -0.07),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final (char, color, angle) in letters)
            Transform.rotate(
              angle: angle,
              child: Text(char, style: style.copyWith(color: color)),
            ),
        ],
      ),
    );
  }

  static String _difficultyName(Difficulty d) {
    switch (d) {
      case Difficulty.normal:   return 'STILL';
      case Difficulty.floating: return 'FLOAT';
      case Difficulty.spinning: return 'SPIN';
      case Difficulty.both:     return 'BOTH';
    }
  }

  Widget _buildOverlay() {
    final modeRecord = _records[_gameOverDifficulty] ?? 0;
    final modeName   = _difficultyName(_gameOverDifficulty);
    final scoreLines = 'You reached level ${_sequence.length}\nScore: $_score'
        '${_isNewRecord ? '\n🏆 New record for $modeName mode: $_score' : (modeRecord > 0 ? '\n$modeName mode record: $modeRecord' : '')}';

    return Container(
      color: const Color(0xED1A1A2A),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGameOverTitle(),
                const SizedBox(height: 20),
                Text(
                  scoreLines,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white60, height: 1.6),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _goToIdle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: const Text(
                      'TRY AGAIN',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildColorLegend(),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _openLeaderboard,
                  child: const Text(
                    '🏆  View leaderboard',
                    style: TextStyle(
                      fontSize: 13, color: Colors.white54,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white24,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _openTipJar,
                  child: const Text(
                    '☕  Support the dev',
                    style: TextStyle(
                      fontSize: 13, color: Colors.white38,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white24,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
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
      (Difficulty.normal,   'STILL'),
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
          onTap: () => setState(() => _difficulty = diff),
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

// ─────────────────────────────────────────────────────────────────────────────
// Record congratulations dialog
// ─────────────────────────────────────────────────────────────────────────────

class _RecordCongratsDialog extends StatefulWidget {
  final int score;
  final String modeName;
  final bool submitted;
  final LeaderboardService leaderboardService;

  const _RecordCongratsDialog({
    required this.score,
    required this.modeName,
    required this.submitted,
    required this.leaderboardService,
  });

  @override
  State<_RecordCongratsDialog> createState() => _RecordCongratsDialogState();
}

class _RecordCongratsDialogState extends State<_RecordCongratsDialog> {
  static const _letterData = [
    ('N', Color(0xFFFF3333),    0.12),
    ('E', Colors.orange,       -0.15),
    ('W', Color(0xFF33FF44),    0.10),
    (' ', Colors.white,         0.00),
    ('R', Colors.yellow,        0.18),
    ('E', Color(0xFF3366FF),   -0.10),
    ('C', Colors.purpleAccent,  0.14),
    ('O', Color(0xFFFF3333),   -0.08),
    ('R', Color(0xFF00FFFF),    0.16),
    ('D', Color(0xFFFF00FF),   -0.12),
    ('!', Colors.white,         0.09),
  ];

  @override
  Widget build(BuildContext context) {
    final lb         = widget.leaderboardService;
    final titleStyle = GoogleFonts.nunito(
      fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2,
    );

    // Determine leaderboard status line.
    Widget leaderboardStatus;
    if (widget.score < kLeaderboardMinScore) {
      leaderboardStatus = const SizedBox.shrink();
    } else if (lb.optedOut) {
      leaderboardStatus = ListenableBuilder(
        listenable: lb,
        builder: (context, _) => _LeaderboardOptRow(lb: lb),
      );
    } else if (widget.submitted) {
      leaderboardStatus = ListenableBuilder(
        listenable: lb,
        builder: (context, _) => _LeaderboardOptRow(lb: lb, submitted: true),
      );
    } else {
      // Signed out or failed — just show the opt-out row so they know it exists.
      leaderboardStatus = ListenableBuilder(
        listenable: lb,
        builder: (context, _) => _LeaderboardOptRow(lb: lb),
      );
    }

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final (char, color, angle) in _letterData)
                    Transform.rotate(
                      angle: angle,
                      child: Text(char, style: titleStyle.copyWith(color: color)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${widget.score}',
              style: GoogleFonts.nunito(
                fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white,
              ),
            ),
            Text(
              '${widget.modeName} mode',
              style: const TextStyle(
                fontSize: 13, color: Colors.white54, letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            leaderboardStatus,
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: Colors.white54, width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    'KEEP GOING',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row: leaderboard submitted tick (or not-signed-in note) + opt-out toggle.
class _LeaderboardOptRow extends StatelessWidget {
  final LeaderboardService lb;
  final bool submitted;

  const _LeaderboardOptRow({required this.lb, this.submitted = false});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color  labelColor;
    if (lb.optedOut) {
      label      = 'Not submitted — leaderboard off';
      labelColor = Colors.white30;
    } else if (submitted) {
      label      = 'Submitted to leaderboard ✓';
      labelColor = const Color(0xFF44DD88);
    } else {
      label      = 'Not submitted (sign in to rank)';
      labelColor = Colors.white38;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: labelColor, height: 1.4),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => lb.setOptedOut(!lb.optedOut),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: lb.optedOut
                  ? Colors.white12
                  : const Color(0xFF44DD88).withValues(alpha: 0.35),
              border: Border.all(
                color: lb.optedOut ? Colors.white24 : const Color(0xFF44DD88),
                width: 1.2,
              ),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: lb.optedOut ? 2 : 18,
                  top: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lb.optedOut ? Colors.white38 : const Color(0xFF44DD88),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
Future<void> showTipJar(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: Colors.black87,
  builder: (_) => const _TipJarDialog(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Tip jar dialog
// ─────────────────────────────────────────────────────────────────────────────

class _TipJarDialog extends StatelessWidget {
  const _TipJarDialog();

  @override
  Widget build(BuildContext context) {
    final ps = PurchaseService();
    final tips = [
      (kProductTipS, '☕', 'Small tip'),
      (kProductTipM, '🎩', 'Medium tip'),
      (kProductTipL, '👑', 'Royal tip'),
    ];

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ListenableBuilder(
          listenable: ps,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('☕', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 16),
              const Text(
                'SUPPORT THE DEV',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Rigobert Says is free and ad-free. If you enjoy it, a tip means a lot — and it will stop these popups for good.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.6),
              ),
              const SizedBox(height: 24),
              ...tips.map((t) {
                final (id, emoji, label) = t;
                final product = ps.product(id);
                final price = product?.price ?? '—';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: ps.loadingPurchase ? null : () async {
                      await ps.buyTip(id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 14, color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 14, color: Colors.white54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Not now — keep playing',
                  style: TextStyle(fontSize: 12, color: Colors.white24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// How To Play page
// ─────────────────────────────────────────────────────────────────────────────

class HowToPlayPage extends StatelessWidget {
  const HowToPlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'HOW TO PLAY',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HowToSection(
                  icon: Icons.lightbulb_outline,
                  iconColor: Color(0xFFFF3333),
                  title: 'The basics',
                  body:
                    'RIGOBERT SAYS is a memory game. The disc lights up a sequence of coloured buttons — watch carefully, then tap them back in the same order. Each round adds one more step.',
                ),
                SizedBox(height: 28),
                _HowToSection(
                  icon: Icons.touch_app_outlined,
                  iconColor: Color(0xFF33FF33),
                  title: 'The buttons',
                  body:
                    'There are three coloured segments on the disc:\n'
                    '  🔴  Red\n'
                    '  🟢  Green\n'
                    '  🔵  Blue\n\n'
                    'Some steps light up two or even all three at once — you must press those buttons simultaneously.',
                ),
                SizedBox(height: 28),
                _HowToSection(
                  icon: Icons.palette_outlined,
                  iconColor: Color(0xFF3366FF),
                  title: 'Colour mixing',
                  body:
                    'When multiple buttons light up together, the disc blends their colours:\n'
                    '  🔴 + 🟢 = Yellow\n'
                    '  🔴 + 🔵 = Magenta\n'
                    '  🟢 + 🔵 = Cyan\n'
                    '  🔴 + 🟢 + 🔵 = White',
                ),
                SizedBox(height: 28),
                _HowToSection(
                  icon: Icons.tune_outlined,
                  iconColor: Colors.purpleAccent,
                  title: 'Difficulty modes',
                  body:
                    'Choose your challenge before you start:\n\n'
                    '  STILL — the disc stays in the centre.\n'
                    '  FLOAT — the disc drifts around the screen.\n'
                    '  SPIN  — the disc slowly rotates.\n'
                    '  BOTH  — the disc floats and spins at the same time.\n\n'
                    'Floating and spinning speeds increase as the sequence grows longer.',
                ),
                SizedBox(height: 28),
                _HowToSection(
                  icon: Icons.emoji_events_outlined,
                  iconColor: Colors.amber,
                  title: 'Scoring',
                  body:
                    'You score points for every correct sequence. Your personal record is saved between sessions — can you beat it?',
                ),
                SizedBox(height: 28),
                _HowToSection(
                  icon: Icons.leaderboard_outlined,
                  iconColor: Color(0xFF00DDFF),
                  title: 'Leaderboards',
                  body:
                    'Every mode has its own global leaderboard — STILL, FLOAT, SPIN, and BOTH are ranked separately.\n\n'
                    'Scores are submitted automatically when you set a personal record of 10 or more. '
                    'Leaderboards use Game Center on iOS and Play Games on Android. '
                    'Signing in is completely optional — the game is fully playable without it.',
                ),
                SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: () => showTipJar(context),
                    child: const Text(
                      '☕  Support the dev',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white38,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white24,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HowToSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _HowToSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: iconColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(body),
      ],
    );
  }
}
