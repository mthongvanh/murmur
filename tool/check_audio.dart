// Command-line script: printing results is its job.
// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:murmur/src/audio_analysis.dart';

/// Dependency-free checks: dart tool/check_audio.dart
void main() {
  final input = tone(1000, 0.1, 4096);
  final frames = Pcm16Analyzer().addBytes(input).toList();
  check(frames.isNotEmpty, 'FFT frames produced');
  final last = frames.last;
  check((last.volume - 0.1 / math.sqrt(2) * 4).abs() < 0.01, 'Known sine RMS');
  final peak = last.bands.indexOf(last.bands.reduce(math.max));
  final expected = (math.log(1000 / 40) / math.log(8000 / 40) * 24).floor();
  check(
    (peak - expected).abs() <= 1,
    'Tone frequency appears in expected band',
  );
  final split = Pcm16Analyzer();
  final chunked = <AudioFrame>[];
  for (var i = 0; i < input.length; i += 37) {
    chunked.addAll(
      split.addBytes(
        Uint8List.sublistView(input, i, math.min(input.length, i + 37)),
      ),
    );
  }
  check(
    chunked.length == frames.length,
    'Odd byte chunk boundaries preserve frame count',
  );
  for (var i = 0; i < frames.length; i++) {
    check(
      (chunked[i].volume - frames[i].volume).abs() < 1e-12,
      'Chunked RMS matches',
    );
    for (var b = 0; b < 24; b++) {
      check(
        (chunked[i].bands[b] - frames[i].bands[b]).abs() < 1e-12,
        'Chunked spectrum matches',
      );
    }
  }
  final silence = Pcm16Analyzer().addBytes(Uint8List(4096)).last;
  check(
    silence.volume == 0 && silence.bands.every((v) => v == 0),
    'Silence stays silent',
  );
  final dc = Uint8List(4096);
  final data = ByteData.sublistView(dc);
  for (var i = 0; i < dc.length; i += 2) {
    data.setInt16(i, 4096, Endian.little);
  }
  check(Pcm16Analyzer().addBytes(dc).last.volume == 0, 'DC offset removed');
  split.reset();
  check(
    split.addBytes(Uint8List(2048)).last.volume == 0,
    'Reset clears ring buffer',
  );
  final sanitized = AudioFrame(
    volume: double.nan,
    bands: [double.infinity, -1, 2],
  );
  check(
    sanitized.volume == 0 && sanitized.bands.join(',') == '0.0,0.0,1.0',
    'External signal sanitization',
  );
  print(
    'Audio checks passed: RMS, FFT tone, chunk boundaries, silence, DC rejection, reset, sanitization.',
  );
}

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

Uint8List tone(double frequency, double amplitude, int count) {
  final bytes = Uint8List(count * 2), data = ByteData(count * 2);
  for (var i = 0; i < count; i++) {
    data.setInt16(
      i * 2,
      (math.sin(i * 2 * math.pi * frequency / 16000) * amplitude * 32767)
          .round(),
      Endian.little,
    );
  }
  bytes.setAll(0, data.buffer.asUint8List());
  return bytes;
}
