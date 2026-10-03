import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'audio_analysis.dart';
import 'controller.dart';

/// Optional microphone adapter. Capture is mono PCM16 at 16 kHz.
/// Existing voice agents can feed VoiceController directly instead.
class MicrophoneInput {
  MicrophoneInput(this.controller);
  final VoiceController controller;
  final AudioRecorder _recorder = AudioRecorder();
  final Pcm16Analyzer _analyzer = Pcm16Analyzer();
  // Cancelled in stop() via a local copy, which the lint cannot follow.
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? _subscription;
  Future<void>? _starting;
  bool _disposed = false, _active = false;
  int _generation = 0;
  bool get isActive => _active;
  void Function(Object error)? onError;
  void Function()? onEnded;

  Future<void> start() {
    if (_disposed) {
      return Future.error(StateError('Microphone input was disposed'));
    }
    if (_active) return Future.value();
    if (_starting != null) return _starting!;
    final generation = ++_generation;
    final future = _start(generation);
    _starting = future;
    return future.whenComplete(() {
      if (identical(_starting, future)) _starting = null;
    });
  }

  Future<void> _start(int generation) async {
    if (!await _recorder.hasPermission()) {
      throw StateError(
        'Microphone permission was denied. Enable it in your system settings.',
      );
    }
    if (_disposed || generation != _generation) return;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        autoGain: false,
        noiseSuppress: false,
      ),
    );
    if (_disposed || generation != _generation) {
      await _recorder.stop();
      return;
    }
    _analyzer.reset();
    controller.useExternalAudio();
    _active = true;
    _subscription = stream.listen(
      (bytes) {
        if (_disposed || generation != _generation) return;
        for (final frame in _analyzer.addBytes(bytes)) {
          controller.addFrame(frame);
        }
      },
      onError: (Object error) {
        _streamEnded(generation, error);
      },
      onDone: () {
        _streamEnded(generation, null);
      },
      cancelOnError: true,
    );
  }

  void _streamEnded(int generation, Object? error) {
    if (_disposed || generation != _generation) return;
    _active = false;
    unawaited(
      stop().catchError((Object e) {
        onError?.call(e);
      }),
    );
    if (error != null) {
      onError?.call(error);
    } else {
      onEnded?.call();
    }
  }

  Future<void> stop() async {
    ++_generation;
    _active = false;
    final pending = _starting;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _recorder.stop();
    _analyzer.reset();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    onError = null;
    onEnded = null;
    await stop();
    await _recorder.dispose();
  }
}
