import 'dart:math' as math;
import 'dart:typed_data';

/// Normalized audio measurements, independent of the capture plugin.
class AudioFrame {
  /// Creates a frame. Out-of-range values are clamped to their range, and
  /// values that are not finite become zero.
  AudioFrame({
    required double volume,
    required List<double> bands,
    List<double> waveform = const [],
  }) : volume = _unit(volume),
       bands = List.unmodifiable(bands.map(_unit)),
       waveform = List.unmodifiable(
         waveform.map((v) => v.isFinite ? v.clamp(-1.0, 1.0).toDouble() : 0.0),
       );

  /// Loudness, 0 to 1.
  final double volume;

  /// Frequency band levels, low to high, each 0 to 1.
  final List<double> bands;

  /// Waveform samples, -1 to 1. Can be empty.
  final List<double> waveform;

  static double _unit(double v) =>
      v.isFinite ? v.clamp(0.0, 1.0).toDouble() : 0;
}

/// Mono signed little-endian PCM16 -> RMS, waveform, logarithmic FFT bands.
/// Handles arbitrary stream chunk boundaries, including split 16-bit samples.
class Pcm16Analyzer {
  /// Creates an analyzer for audio at [sampleRate] Hz. Each frame analyses
  /// the last [fftSize] samples, which must be a power of two, and a new frame
  /// comes every [hopSize] samples. Throws an [ArgumentError] if a setting is
  /// out of range.
  Pcm16Analyzer({
    this.sampleRate = 16000,
    this.fftSize = 1024,
    this.hopSize = 512,
    this.bandCount = 24,
  }) {
    if (sampleRate < 1000 ||
        fftSize < 32 ||
        (fftSize & (fftSize - 1)) != 0 ||
        hopSize < 1 ||
        hopSize > fftSize ||
        bandCount < 1) {
      throw ArgumentError('Invalid PCM analysis configuration');
    }
    _ring = Float64List(fftSize);
    _window = Float64List.fromList(
      List.generate(
        fftSize,
        (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (fftSize - 1)),
      ),
    );
  }

  /// Samples per second of the incoming audio.
  final int sampleRate;

  /// Samples in each analysis window. A power of two, at least 32.
  final int fftSize;

  /// Samples between frames, from 1 to [fftSize].
  final int hopSize;

  /// How many frequency bands each frame has.
  final int bandCount;

  late Float64List _ring, _window;
  int _write = 0, _count = 0, _sinceFrame = 0;
  int? _lowByte;

  /// Adds PCM bytes and returns the frames they complete, which may be none.
  /// Chunks can split anywhere, even inside a sample. The result is lazy:
  /// iterate it, or the bytes are not consumed.
  Iterable<AudioFrame> addBytes(Uint8List bytes) sync* {
    for (final byte in bytes) {
      if (_lowByte == null) {
        _lowByte = byte;
        continue;
      }
      var signed = _lowByte! | (byte << 8);
      _lowByte = null;
      if (signed >= 32768) signed -= 65536;
      _ring[_write] = signed / 32768;
      _write = (_write + 1) % fftSize;
      _count = math.min(_count + 1, fftSize);
      _sinceFrame++;
      if (_count == fftSize && _sinceFrame >= hopSize) {
        _sinceFrame = 0;
        yield _analyze();
      }
    }
  }

  /// Clears buffered audio, ready for a new stream.
  void reset() {
    _ring.fillRange(0, fftSize, 0);
    _write = 0;
    _count = 0;
    _sinceFrame = 0;
    _lowByte = null;
  }

  AudioFrame _analyze() {
    final samples = Float64List(fftSize);
    var mean = 0.0;
    for (var i = 0; i < fftSize; i++) {
      samples[i] = _ring[(_write + i) % fftSize];
      mean += samples[i];
    }
    mean /= fftSize;
    final real = Float64List(fftSize), imaginary = Float64List(fftSize);
    var energy = 0.0, windowSum = 0.0;
    for (var i = 0; i < fftSize; i++) {
      final v = samples[i] - mean;
      energy += v * v;
      real[i] = v * _window[i];
      windowSum += _window[i];
    }
    // In-place radix-2 Cooley-Tukey FFT, O(N log N).
    for (var i = 1, j = 0; i < fftSize; i++) {
      var bit = fftSize >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tmp = real[i];
        real[i] = real[j];
        real[j] = tmp;
      }
    }
    for (var length = 2; length <= fftSize; length <<= 1) {
      final angle = -2 * math.pi / length;
      final wrStep = math.cos(angle), wiStep = math.sin(angle);
      for (var start = 0; start < fftSize; start += length) {
        var wr = 1.0, wi = 0.0;
        for (var j = 0; j < length ~/ 2; j++) {
          final a = start + j, b = a + length ~/ 2;
          final tr = real[b] * wr - imaginary[b] * wi;
          final ti = real[b] * wi + imaginary[b] * wr;
          real[b] = real[a] - tr;
          imaginary[b] = imaginary[a] - ti;
          real[a] += tr;
          imaginary[a] += ti;
          final nextWr = wr * wrStep - wi * wiStep;
          wi = wr * wiStep + wi * wrStep;
          wr = nextWr;
        }
      }
    }
    final bands = List<double>.filled(bandCount, 0);
    final low = math.max(40.0, sampleRate / fftSize);
    final high = math.min(8000.0, sampleRate / 2.0);
    for (var b = 0; b < bandCount; b++) {
      final f0 = low * math.pow(high / low, b / bandCount);
      final f1 = low * math.pow(high / low, (b + 1) / bandCount);
      final start = (f0 * fftSize / sampleRate)
          .floor()
          .clamp(1, fftSize ~/ 2 - 1)
          .toInt();
      final end = (f1 * fftSize / sampleRate)
          .ceil()
          .clamp(start + 1, fftSize ~/ 2)
          .toInt();
      var peak = 0.0;
      for (var k = start; k < end; k++) {
        final magnitude =
            2 *
            math.sqrt(real[k] * real[k] + imaginary[k] * imaginary[k]) /
            windowSum;
        peak = math.max(peak, magnitude);
      }
      bands[b] = (peak * 5).clamp(0.0, 1.0).toDouble();
    }
    return AudioFrame(
      volume: math.sqrt(energy / fftSize) * 4,
      bands: bands,
      waveform: List.generate(128, (i) => samples[i * fftSize ~/ 128]),
    );
  }
}
