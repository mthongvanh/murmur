import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'audio_analysis.dart';
import 'models.dart';

/// A sound-triggered ripple, shared by every view of the same controller.
class RipplePulse {
  /// Creates a ripple that started at [time] with the given [strength].
  const RipplePulse({required this.time, required this.strength});

  /// The [VoiceController.time] at which the ripple started.
  final double time;

  /// How strong the ripple is, 0 to 1.
  final double strength;
}

/// One shared clock for the main indicator and any preview thumbnails.
/// Feed existing agent audio with [addFrame]; no microphone plugin is required.
class VoiceController extends ChangeNotifier {
  /// Creates a controller whose clock runs on [vsync]. It starts in demo
  /// mode, in the listening state.
  VoiceController({
    required TickerProvider vsync,
    this._style = const VoiceStyle(),
  }) {
    _ticker = vsync.createTicker(_tick)..start();
  }
  late final Ticker _ticker;
  VoiceStyle _style;

  /// How the indicators are drawn, unless an indicator sets its own style.
  VoiceStyle get style => _style;
  set style(VoiceStyle value) {
    _style = value;
    notifyListeners();
  }

  AgentState _state = AgentState.listening;

  /// The agent state the indicators show. A change eases in over about a
  /// third of a second.
  AgentState get state => _state;
  set state(AgentState value) {
    _state = value;
    notifyListeners();
  }

  bool _demo = true, _paused = false, _disposed = false;

  /// Whether the built-in demo signal drives the indicators, rather than
  /// audio passed to [addFrame].
  bool get isDemo => _demo;

  /// Whether the clock and signal are paused. See [setPaused].
  bool get paused => _paused;
  double _time = 0, _volume = 0, _rawVolume = 0, _lastFeedTime = 0;

  /// Seconds of animation time, not counting time spent paused.
  double get time => _time;

  /// The level the indicators draw, 0 to 1, after [VoiceStyle.sensitivity]
  /// and smoothing.
  double get volume => _volume;

  /// The latest input level, 0 to 1, before sensitivity and smoothing.
  double get rawVolume => _rawVolume;
  final List<double> _bands = List.filled(24, 0);

  /// The levels of 24 frequency bands, low to high, each 0 to 1, after
  /// sensitivity and smoothing.
  List<double> get bands => List.unmodifiable(_bands);
  List<double> _targetBands = List.filled(24, 0), _waveform = const [];

  /// The latest waveform samples, -1 to 1. Empty in demo mode and when no
  /// audio has arrived recently.
  List<double> get waveform => _waveform;
  Duration? _previous;

  /// [rawVolume], updated about 12 times a second, for meters that should
  /// not rebuild on every frame.
  final ValueNotifier<double> inputLevel = ValueNotifier(0);
  double _meterTime = 0;
  final List<RipplePulse> _ripples = [];

  /// Recent sound-triggered ripples, oldest first. Each lasts 3.2 seconds,
  /// and at most 10 are kept.
  List<RipplePulse> get ripples => List.unmodifiable(_ripples);
  double _lastRippleTime = -1, _previousRippleLevel = 0;

  /// Drives the indicators from the built-in demo signal, and unpauses.
  void useDemo() {
    _demo = true;
    _paused = false;
    _waveform = const [];
    _previous = null;
    notifyListeners();
  }

  /// Switches to audio passed to [addFrame], starting from silence, and
  /// unpauses. If no frame arrives for a quarter of a second, the level falls
  /// back to silence.
  void useExternalAudio() {
    _demo = false;
    _paused = false;
    _rawVolume = 0;
    _targetBands = List.filled(24, 0);
    _lastFeedTime = _time;
    _waveform = const [];
    notifyListeners();
  }

  /// Pauses or resumes the clock. While paused, the level falls to silence
  /// and no ripples start.
  void setPaused(bool value) {
    _paused = value;
    notifyListeners();
  }

  /// Feeds one frame of audio and leaves demo mode. The frame's bands are
  /// mapped onto the controller's 24.
  void addFrame(AudioFrame frame) {
    if (_disposed) return;
    _demo = false;
    _rawVolume = frame.volume;
    _lastFeedTime = _time;
    _targetBands = List.generate(
      24,
      (i) => frame.bands.isEmpty
          ? 0.0
          : frame.bands[math.min(
              frame.bands.length - 1,
              i * frame.bands.length ~/ 24,
            )],
    );
    _waveform = frame.waveform;
  }

  /// Restores the default style and the listening state, clears motion and
  /// ripples, and returns to demo mode.
  void reset() {
    _style = const VoiceStyle();
    _state = AgentState.listening;
    _volume = 0;
    _velocity = 0;
    _bandVelocities.fillRange(0, 24, 0);
    _ripples.clear();
    _lastRippleTime = -1;
    _previousRippleLevel = 0;
    useDemo();
  }

  /// Suspend the clock when the owning screen/app is not visible.
  void suspend() {
    _ticker.stop();
    _previous = null;
  }

  /// Restarts the clock after [suspend].
  void resume() {
    if (!_disposed && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    }
  }

  double _velocity = 0;
  final List<double> _bandVelocities = List.filled(24, 0);

  /// One step of a damped spring from [value] toward [target]; [index] is
  /// the band whose velocity it carries, or -1 for the volume. Stepped in
  /// pieces of at most 1/120 s, so a slow frame cannot make it fly apart.
  double _spring(double value, double target, double dt, int index) {
    // Smoothing 0.7, the default, is a spring of about 2.4 Hz.
    var omega = 4 + 35 * (1 - _style.smoothing);
    var zeta = 1 - _style.bounce;
    // It springs past a rising sound, but settles from a falling one, a
    // little slower, without dropping below and stopping dead at zero.
    if (target < value) {
      omega *= 0.7;
      zeta = 1;
    }
    var v = index < 0 ? _velocity : _bandVelocities[index];
    var x = value;
    final steps = (dt * 120).ceil().clamp(1, 12);
    final h = dt / steps;
    for (var s = 0; s < steps; s++) {
      v += (omega * omega * (target - x) - 2 * zeta * omega * v) * h;
      x += v * h;
      // Below nothing there is nothing to bounce off: it settles at zero.
      if (x < 0) {
        x = 0;
        v = 0;
      }
    }
    if (index < 0) {
      _velocity = v;
    } else {
      _bandVelocities[index] = v;
    }
    return x;
  }

  /// How far the thinking look is shown, 0 to 1. It eases over about a
  /// third of a second whenever [state] changes.
  double get thinkingMix => _thinkingMix;

  /// How far the idle look is shown, 0 to 1, eased like [thinkingMix].
  double get idleMix => _idleMix;
  double _thinkingMix = 0, _idleMix = 0;
  bool _mixed = false;

  void _tick(Duration elapsed) {
    final dt = _previous == null
        ? 1 / 60
        : ((elapsed - _previous!).inMicroseconds / 1e6)
              .clamp(0.0, 0.1)
              .toDouble();
    _previous = elapsed;
    if (!_paused) _time += dt;
    if (_demo) {
      _rawVolume = _paused
          ? 0
          : math.max(
              0.0,
              (0.25 +
                      0.2 * math.sin(_time * 2.3) +
                      0.15 * math.sin(_time * 7.1)) *
                  (0.45 + 0.55 * math.max(0.0, math.sin(_time * 0.8))),
            );
      for (var i = 0; i < 24; i++) {
        _targetBands[i] = _paused
            ? 0
            : _rawVolume * (0.6 + 0.4 * math.sin(_time * 3 + i * 0.8));
      }
    } else if (_paused || _time - _lastFeedTime > 0.25) {
      // Audio interruptions decay rather than leaving a stuck loud indicator.
      _rawVolume = 0;
      _targetBands.fillRange(0, 24, 0);
      _waveform = const [];
    }
    final target = (_rawVolume * _style.sensitivity).clamp(0.0, 1.0).toDouble();
    if (_style.bounce > 0) {
      _volume = _spring(_volume, target, dt, -1);
      for (var i = 0; i < 24; i++) {
        _bands[i] = _spring(
          _bands[i],
          (_targetBands[i] * _style.sensitivity).clamp(0.0, 1.0),
          dt,
          i,
        );
      }
    } else {
      final factor = 1 - math.pow(_style.smoothing, dt * 60).toDouble();
      _volume += (target - _volume) * factor;
      _velocity = 0;
      for (var i = 0; i < 24; i++) {
        final targetBand = (_targetBands[i] * _style.sensitivity).clamp(
          0.0,
          1.0,
        );
        _bands[i] += (targetBand - _bands[i]) * factor;
        _bandVelocities[i] = 0;
      }
    }
    final thinkingTarget = _state == AgentState.thinking ? 1.0 : 0.0;
    final idleTarget = _state == AgentState.idle ? 1.0 : 0.0;
    if (!_mixed) {
      // The first frame shows the state as it is.
      _mixed = true;
      _thinkingMix = thinkingTarget;
      _idleMix = idleTarget;
    } else {
      final ease = 1 - math.exp(-dt / 0.12);
      _thinkingMix += (thinkingTarget - _thinkingMix) * ease;
      _idleMix += (idleTarget - _idleMix) * ease;
    }
    final rippleStrength = _state == AgentState.idle
        ? 0.0
        : _state == AgentState.thinking
        ? 0.12
        : _volume;
    if (!_paused &&
        rippleStrength > 0.055 &&
        (_time - _lastRippleTime > 0.55 ||
            (rippleStrength - _previousRippleLevel > 0.13 &&
                _time - _lastRippleTime > 0.14))) {
      _ripples.add(RipplePulse(time: _time, strength: rippleStrength));
      _lastRippleTime = _time;
    }
    _previousRippleLevel = rippleStrength;
    _ripples.removeWhere((p) => _time - p.time >= 3.2);
    if (_ripples.length > 10) _ripples.removeRange(0, _ripples.length - 10);
    _meterTime += dt;
    if (_meterTime >= 0.08) {
      _meterTime = 0;
      inputLevel.value = _rawVolume;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    inputLevel.dispose();
    super.dispose();
  }
}
