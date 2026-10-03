import 'dart:async';
import 'package:flutter/material.dart';
import 'package:murmur/murmur.dart';

void main() => runApp(const MurmurStudioApp());
const mint = Color(0xFFA4F5CE),
    stageColor = Color(0xFF171B1B),
    logoTile = Color(0xFF242B27);

/// Studio palette for one brightness. The stage stays dark in both themes.
class StudioColors {
  const StudioColors({
    required this.ink,
    required this.muted,
    required this.accent,
    required this.background,
    required this.surface,
    required this.well,
    required this.panel,
    required this.tint,
    required this.line,
    required this.border,
    required this.subtle,
    required this.thumbnail,
    required this.meterOn,
    required this.meterOff,
    required this.error,
    required this.stageBorder,
  });
  final Color ink, muted, accent, background, surface, well, panel, tint;
  final Color line, border, subtle, thumbnail, meterOn, meterOff, error;
  final Color stageBorder;

  static const light = StudioColors(
    ink: Color(0xFF242B27),
    muted: Color(0xFF7C877F),
    accent: Color(0xFF527C60),
    background: Color(0xFFF7F8F7),
    surface: Colors.white,
    well: Color(0xFFF0F3F0),
    panel: Color(0xFFFAFCF9),
    tint: Color(0xFFF3F6F2),
    line: Color(0xFFE0E6E0),
    border: Color(0xFFDDE4DD),
    subtle: Color(0xFFD0DAD2),
    thumbnail: Color(0xFF4E8867),
    meterOn: Color(0xFF83B394),
    meterOff: Color(0xFFE1E8E0),
    error: Color(0xFFAD553D),
    stageBorder: Colors.transparent,
  );
  static const dark = StudioColors(
    ink: Color(0xFFE4EAE6),
    muted: Color(0xFF93A098),
    accent: Color(0xFF86BD98),
    background: Color(0xFF0E1110),
    surface: Color(0xFF181C1B),
    well: Color(0xFF111413),
    panel: Color(0xFF131716),
    tint: Color(0xFF1F2523),
    line: Color(0xFF2A302E),
    border: Color(0xFF2E3532),
    subtle: Color(0xFF47514C),
    thumbnail: Color(0xFF7FC59C),
    meterOn: Color(0xFF83B394),
    meterOff: Color(0xFF262D2A),
    error: Color(0xFFE8907A),
    stageBorder: Color(0xFF262D2A),
  );
  static StudioColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData studioTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? StudioColors.dark
      : StudioColors.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: StudioColors.light.accent,
      brightness: brightness,
      surface: c.surface,
    ),
    scaffoldBackgroundColor: c.background,
    textTheme: TextTheme(bodyMedium: TextStyle(fontSize: 16, color: c.ink)),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: c.accent),
    ),
  );
}

class MurmurStudioApp extends StatefulWidget {
  const MurmurStudioApp({super.key});
  @override
  State<MurmurStudioApp> createState() => _MurmurStudioAppState();
}

class _MurmurStudioAppState extends State<MurmurStudioApp> {
  ThemeMode _themeMode = ThemeMode.system;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Murmur Studio',
    theme: studioTheme(Brightness.light),
    darkTheme: studioTheme(Brightness.dark),
    themeMode: _themeMode,
    home: StudioScreen(
      onDarkModeChanged: (dark) => setState(() {
        _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
      }),
    ),
  );
}

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, this.onDarkModeChanged});
  final ValueChanged<bool>? onDarkModeChanged;
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final MurmurController controller;
  late final MicrophoneInput microphone;
  MurmurShape shape = MurmurShape.contourBloom;
  bool _loading = true;
  late final AnimationController _progressAnimation;
  double get _progress => _progressAnimation.value * 100;
  bool _busy = false;
  StudioColors get c => StudioColors.of(context);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = MurmurController(vsync: this);
    controller.suspend();
    _progressAnimation =
        AnimationController(
            vsync: this,
            duration: const Duration(seconds: 8),
            value: 0.42,
          )
          ..addListener(() {
            if (mounted) setState(() {});
          })
          ..addStatusListener((_) {
            if (mounted) setState(() {});
          });
    microphone = MicrophoneInput(controller);
    microphone.onError = (error) {
      if (mounted) {
        setState(() {
          _error = 'Microphone stopped: $error';
          controller.useDemo();
        });
      }
    };
    microphone.onEnded = () {
      if (mounted) {
        setState(() {
          _error = 'Microphone disconnected. Switched to demo.';
          controller.useDemo();
        });
      }
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_loading) controller.resume();
    } else {
      controller.suspend();
      _progressAnimation.stop();
      // Do not cancel on inactive: OS permission prompts also use this state.
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        unawaited(_stopForBackground());
      }
    }
  }

  Future<void> _stopForBackground() async {
    try {
      await microphone.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        controller.useDemo();
        _error = 'Microphone stopped while the app was in the background.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(microphone.dispose());
    _progressAnimation.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _startMic() async {
    if (_busy || microphone.isActive) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await microphone.start();
    } catch (error) {
      if (mounted) {
        _error = '$error';
        controller.useDemo();
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _demo({bool pause = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await microphone.stop();
    } catch (error) {
      _error = 'Could not stop microphone: $error';
    } finally {
      if (mounted) {
        setState(() {
          controller.useDemo();
          controller.setPaused(pause);
          _busy = false;
        });
      }
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    await _demo();
    if (mounted) {
      setState(() {
        shape = _loading ? MurmurShape.contourBloom : MurmurShape.waterSurface;
        controller.reset();
        _progressAnimation.stop();
        _progressAnimation.value = 0.42;
        if (_loading) controller.suspend();
      });
    }
  }

  void _style(MurmurStyle value) => setState(() {
    controller.style = value;
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 76,
      titleSpacing: 24,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: logoTile,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: mint, size: 25),
          ),
          const SizedBox(width: 10),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'murmur',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: 'studio',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
              ],
            ),
            style: TextStyle(fontSize: 24, letterSpacing: -1),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _dark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: widget.onDarkModeChanged == null
              ? null
              : () => widget.onDarkModeChanged!(!_dark),
          icon: Icon(
            _dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
          ),
          color: c.muted,
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: _busy ? null : _reset,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset'),
          style: TextButton.styleFrom(foregroundColor: c.muted),
        ),
        const SizedBox(width: 14),
      ],
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1000;
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: _workspace(),
                            ),
                          ),
                          SizedBox(width: 310, child: _controls()),
                        ],
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: _workspace(),
                          ),
                          _controls(),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    ),
  );
  Widget _workspace() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _loading
            ? 'DETERMINATE LOADING EXPLORATIONS'
            : 'VOICE AGENT EXPLORATIONS',
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.6,
          color: c.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _loading ? 'Give progress a shape.' : 'Make listening visible.',
        style: const TextStyle(
          fontSize: 34,
          letterSpacing: -1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _loading
            ? 'Three ways to see exactly how far you’ve come.'
            : 'Find the right feeling for your voice agent.',
        style: TextStyle(color: c.muted, fontSize: 16),
      ),
      const SizedBox(height: 25),
      _stage(),
      const SizedBox(height: 20),
      Text(
        'PREVIEW MODE',
        style: TextStyle(fontSize: 12, color: c.muted, letterSpacing: 1),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Voice agent'),
            selected: !_loading,
            showCheckmark: false,
            onSelected: _busy ? null : (_) => _switchMode(false),
          ),
          ChoiceChip(
            label: const Text('Loading'),
            selected: _loading,
            showCheckmark: false,
            onSelected: _busy ? null : (_) => _switchMode(true),
          ),
        ],
      ),
      if (!_loading) ...[
        const SizedBox(height: 18),
        Text(
          'AGENT STATE',
          style: TextStyle(fontSize: 12, color: c.muted, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AgentState.values
              .map(
                (state) => ChoiceChip(
                  label: Text(_title(state.name)),
                  selected: controller.state == state,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    controller.state = state;
                  }),
                ),
              )
              .toList(),
        ),
      ],
      const SizedBox(height: 28),
      Divider(color: c.line),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 8,
        children: [
          Text(
            _loading ? 'Choose your loading indicator' : 'Choose your shape',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(
            _loading ? '3 progress styles' : '17 ways to be heard',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
        ],
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth > 600
              ? 3
              : c.maxWidth > 330
              ? 2
              : 1;
          final width = (c.maxWidth - (columns - 1) * 12) / columns;
          final options = _loading
              ? MurmurLoading.supportedShapes
              : [
                  MurmurShape.waterSurface,
                  MurmurShape.foldedLight,
                  MurmurShape.gravityWell,
                  MurmurShape.phaseWeave,
                  MurmurShape.inkEclipse,
                  ...MurmurShape.values.where((s) => s.index < 12),
                ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options
                .map((s) => SizedBox(width: width, child: _shapeCard(s)))
                .toList(),
          );
        },
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 30,
        runSpacing: 8,
        children: [
          Text(
            'Made for exploring. Tuned by you.',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
          Text(
            'Audio stays on your device.',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
        ],
      ),
    ],
  );
  Widget _indicator(
    Size size, {
    MurmurShape? selectedShape,
    bool thumbnail = false,
  }) {
    final s = selectedShape ?? shape;
    final style = thumbnail
        ? controller.style.copyWith(color: c.thumbnail, scale: 1, glow: false)
        : controller.style;
    return _loading
        ? MurmurLoading(
            progress: _progressAnimation.value,
            shape: s,
            style: style,
            size: size,
            thumbnail: thumbnail,
          )
        : Murmur(
            controller: controller,
            shape: s,
            style: style,
            size: size,
            thumbnail: thumbnail,
          );
  }

  Future<void> _switchMode(bool loading) async {
    if (_busy || loading == _loading) return;
    _progressAnimation.stop();
    if (loading) {
      await _demo();
      if (!mounted) return;
      controller.suspend();
      setState(() {
        _loading = true;
        if (!MurmurLoading.supportedShapes.contains(shape)) {
          shape = MurmurShape.waterSurface;
        }
      });
    } else {
      controller.resume();
      setState(() {
        _loading = false;
      });
    }
  }

  void _setProgress(double value) {
    _progressAnimation.stop();
    _progressAnimation.value = value / 100;
    setState(() {});
  }

  void _toggleProgress() {
    if (_progressAnimation.isAnimating) {
      _progressAnimation.stop();
    } else {
      if (_progressAnimation.value >= 1) _progressAnimation.value = 0;
      _progressAnimation.forward();
    }
    setState(() {});
  }

  Widget _stage() => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 390,
      color: stageColor,
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: c.stageBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            top: 20,
            bottom: 75,
            child: LayoutBuilder(
              builder: (_, c) =>
                  Center(child: _indicator(Size(c.maxWidth, c.maxHeight))),
            ),
          ),
          Positioned(
            top: 17,
            left: 22,
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: mint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'LIVE PREVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: Color(0xFF98A69D),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 5,
            right: 12,
            child: IconButton(
              tooltip: 'Expand preview',
              onPressed: _expand,
              icon: const Icon(Icons.fullscreen, color: Color(0xFF98A69D)),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Text(
                  _loading
                      ? '${_progress >= 100 ? 100 : _progress.floor()}%'
                      : _title(controller.state.name),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 7),
                Text(
                  _loading
                      ? (_progress >= 100
                            ? 'Complete'
                            : _progressAnimation.isAnimating
                            ? 'Loading…'
                            : 'Drag the progress slider to explore.')
                      : controller.state == AgentState.idle
                      ? 'Ready when you are.'
                      : controller.state == AgentState.thinking
                      ? 'A little motion while your agent thinks.'
                      : !controller.isDemo
                      ? 'Your sound is shaping the motion.'
                      : controller.paused
                      ? 'The demo is paused.'
                      : 'A demo signal is moving your indicator.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8D9992),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 22,
            right: 22,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 5,
              children: [
                Text(
                  '${(shape.index + 1).toString().padLeft(2, '0')} / ${shape.label}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8D9992),
                  ),
                ),
                Text(
                  _loading
                      ? (_progress >= 100 ? 'COMPLETE' : 'DETERMINATE PROGRESS')
                      : controller.isDemo
                      ? 'DEMO INPUT'
                      : 'MICROPHONE INPUT',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: Color(0xFF8D9992),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _expand() => showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: stageColor,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (_, child) => LayoutBuilder(
                  builder: (_, c) =>
                      Center(child: _indicator(Size(c.maxWidth, c.maxHeight))),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close expanded preview',
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 28,
              left: 24,
              child: Text(
                shape.label,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _shapeCard(MurmurShape s) {
    final selected = shape == s;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? c.accent : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            shape = s;
          }),
          child: Column(
            children: [
              Container(
                height: 98,
                color: c.well,
                child: LayoutBuilder(
                  builder: (_, c) => Center(
                    child: _indicator(
                      Size(c.maxWidth, 98),
                      selectedShape: s,
                      thumbnail: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loading
                                ? (s == MurmurShape.waterSurface
                                      ? 'Radial fill · surface'
                                      : s == MurmurShape.spectrumHalo
                                      ? 'Clockwise fill · spectrum'
                                      : 'Layered fill · bloom')
                                : s.description,
                            style: TextStyle(fontSize: 12, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: selected ? c.accent : c.subtle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() => Container(
    color: c.surface,
    padding: const EdgeInsets.all(25),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, color: c.muted, size: 20),
            SizedBox(width: 9),
            Text(
              'The controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (!_loading) ...[
          const SizedBox(height: 28),
          _sectionTitle('Audio source'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Demo'),
                selected: controller.isDemo,
                showCheckmark: false,
                onSelected: _busy ? null : (_) => _demo(),
              ),
              ChoiceChip(
                label: const Text('Microphone'),
                selected: !controller.isDemo,
                showCheckmark: false,
                onSelected: _busy ? null : (_) => _startMic(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _busy
                ? 'Connecting audio…'
                : controller.isDemo
                ? 'A simulated voice. No microphone needed.'
                : 'Microphone is on. Sound is processed locally.',
            style: TextStyle(fontSize: 13, color: c.muted, height: 1.6),
          ),
          const SizedBox(height: 17),
          ValueListenableBuilder<double>(
            valueListenable: controller.inputLevel,
            builder: (_, level, child) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.panel,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Input level', style: TextStyle(fontSize: 13)),
                      Text(
                        '${(level * 100).round()}%',
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(
                      24,
                      (i) => Expanded(
                        child: Container(
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: i < (level * 24).round()
                                ? c.meterOn
                                : c.meterOff,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quiet',
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                      Text(
                        'Loud',
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      if (!controller.isDemo) {
                        _demo(pause: true);
                      } else {
                        setState(() {
                          controller.setPaused(!controller.paused);
                        });
                      }
                    },
              icon: Icon(
                !controller.isDemo
                    ? Icons.stop
                    : controller.paused
                    ? Icons.play_arrow
                    : Icons.pause,
                size: 17,
              ),
              label: Text(
                !controller.isDemo
                    ? 'Stop microphone'
                    : controller.paused
                    ? 'Play demo'
                    : 'Pause demo',
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: c.error, fontSize: 13, height: 1.5),
                ),
              ),
            ),
        ] else
          ..._loadingControls(),
        _divider(),
        _sectionTitle('Appearance'),
        const SizedBox(height: 17),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Accent color', style: TextStyle(fontSize: 14)),
            Text(
              '#${controller.style.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    mint,
                    const Color(0xFF92BAFF),
                    const Color(0xFFC5A1FF),
                    const Color(0xFFFFAB83),
                    const Color(0xFFF6D975),
                  ]
                  .map(
                    (color) => Semantics(
                      button: true,
                      selected: color == controller.style.color,
                      label: 'Accent ${color.toARGB32().toRadixString(16)}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () =>
                            _style(controller.style.copyWith(color: color)),
                        child: Container(
                          width: 38,
                          height: 38,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == controller.style.color
                                  ? c.accent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _customColor,
          icon: const Icon(Icons.palette_outlined, size: 17),
          label: const Text('Custom color'),
        ),
        _slider(
          'Scale',
          '${(controller.style.scale * 100).round()}%',
          controller.style.scale,
          0.6,
          1.4,
          (v) => _style(controller.style.copyWith(scale: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Soft glow', style: TextStyle(fontSize: 14)),
          value: controller.style.glow,
          onChanged: (v) => _style(controller.style.copyWith(glow: v)),
        ),
        if (!_loading) ...[
          _divider(),
          _sectionTitle('Response'),
          _slider(
            'Sensitivity',
            '${controller.style.sensitivity.toStringAsFixed(1)}×',
            controller.style.sensitivity,
            0.5,
            4,
            (v) => _style(controller.style.copyWith(sensitivity: v)),
          ),
          _slider(
            'Smoothing',
            '${(controller.style.smoothing * 100).round()}%',
            controller.style.smoothing,
            0,
            0.95,
            (v) => _style(controller.style.copyWith(smoothing: v)),
          ),
        ],
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.tint,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 20, color: c.accent),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loading
                          ? 'Progress, at your pace.'
                          : 'Give it a little life.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      _loading
                          ? 'Scrub from 0 to 100%. All three indicators follow the same progress value.'
                          : 'Try talking, clapping, or playing music. Each shape responds in its own way.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  List<Widget> _loadingControls() => [
    const SizedBox(height: 28),
    _sectionTitle('Loading progress'),
    _slider(
      'Progress',
      '${_progress >= 100 ? 100 : _progress.floor()}%',
      _progress,
      0,
      100,
      _setProgress,
    ),
    Text(
      'Set an exact value, or play a sample loading sequence.',
      style: TextStyle(fontSize: 13, color: c.muted, height: 1.6),
    ),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _toggleProgress,
        icon: Icon(
          _progressAnimation.isAnimating
              ? Icons.pause
              : _progress >= 100
              ? Icons.replay
              : Icons.play_arrow,
          size: 17,
        ),
        label: Text(
          _progressAnimation.isAnimating
              ? 'Pause preview'
              : _progress >= 100
              ? 'Replay preview'
              : 'Play preview',
        ),
      ),
    ),
    Center(
      child: TextButton(
        onPressed: () => _setProgress(0),
        child: const Text('Reset progress'),
      ),
    ),
  ];
  Widget _slider(
    String title,
    String display,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(top: 23),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            Text(display, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          label: display,
          onChanged: onChanged,
          semanticFormatterCallback: (_) => '$title $display',
        ),
      ],
    ),
  );
  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );
  Widget _divider() => Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Divider(height: 1, color: c.line),
  );
  String _title(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
  Future<void> _customColor() async {
    final input = TextEditingController(
      text: controller.style.color
          .toARGB32()
          .toRadixString(16)
          .substring(2)
          .toUpperCase(),
    );
    String? error;
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Accent color'),
          content: TextField(
            controller: input,
            autofocus: true,
            maxLength: 7,
            decoration: InputDecoration(
              labelText: 'Hex color',
              hintText: 'A4F5CE',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final hex = input.text.trim().replaceFirst('#', '');
                if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
                  update(() {
                    error = 'Enter six hexadecimal digits.';
                  });
                  return;
                }
                Navigator.pop(context, Color(int.parse('FF$hex', radix: 16)));
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    // Let the dialog's closing animation release its editable text state first.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (result != null && mounted) {
      _style(controller.style.copyWith(color: result));
    }
  }
}
