import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'audio_analysis.dart';
import 'models.dart';

/// A sound-triggered ripple, shared by every view of the same controller.
class RipplePulse {
  const RipplePulse({required this.time, required this.strength});
  final double time, strength;
}

/// One shared clock for the main indicator and any preview thumbnails.
/// Feed existing agent audio with [addFrame]; no microphone plugin is required.
class VoiceController extends ChangeNotifier {
  VoiceController({
    required TickerProvider vsync,
    this._style = const VoiceStyle(),
  }) {
    _ticker = vsync.createTicker(_tick)..start();
  }
  late final Ticker _ticker;
  VoiceStyle _style;
  VoiceStyle get style => _style;
  set style(VoiceStyle value) {
    _style = value;
    notifyListeners();
  }

  AgentState _state = AgentState.listening;
  AgentState get state => _state;
  set state(AgentState value) {
    _state = value;
    notifyListeners();
  }

  bool _demo = true, _paused = false, _disposed = false;
  bool get isDemo => _demo;
  bool get paused => _paused;
  double _time = 0, _volume = 0, _rawVolume = 0, _lastFeedTime = 0;
  double get time => _time;
  double get volume => _volume;
  double get rawVolume => _rawVolume;
  final List<double> _bands = List.filled(24, 0);
  List<double> get bands => List.unmodifiable(_bands);
  List<double> _targetBands = List.filled(24, 0), _waveform = const [];
  List<double> get waveform => _waveform;
  Duration? _previous;
  final ValueNotifier<double> inputLevel = ValueNotifier(0);
  double _meterTime = 0;
  final List<RipplePulse> _ripples = [];
  List<RipplePulse> get ripples => List.unmodifiable(_ripples);
  double _lastRippleTime = -1, _previousRippleLevel = 0;

  void useDemo() {
    _demo = true;
    _paused = false;
    _waveform = const [];
    _previous = null;
    notifyListeners();
  }

  void useExternalAudio() {
    _demo = false;
    _paused = false;
    _rawVolume = 0;
    _targetBands = List.filled(24, 0);
    _lastFeedTime = _time;
    _waveform = const [];
    notifyListeners();
  }

  void setPaused(bool value) {
    _paused = value;
    notifyListeners();
  }

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

  /// How far each state's look is shown, 0 to 1, eased over about a third
  /// of a second whenever the state changes.
  double get thinkingMix => _thinkingMix;
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
