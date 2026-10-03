import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/murmur.dart';
import '../tool/check_audio.dart' as audio_checks;

void main() {
  test(
    'PCM analysis has known RMS and frequency output across chunk boundaries',
    audio_checks.main,
  );
  testWidgets(
    'All seventeen shapes paint in every agent state at small and large sizes',
    (tester) async {
      final controller = MurmurController(vsync: const TestVSync());
      for (final size in [const Size(100, 70), const Size(700, 400)]) {
        for (final state in AgentState.values) {
          controller.state = state;
          for (final shape in MurmurShape.values) {
            await tester.pumpWidget(
              MaterialApp(
                home: Center(
                  child: Murmur(
                    controller: controller,
                    shape: shape,
                    size: size,
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 50));
            expect(
              tester.takeException(),
              isNull,
              reason: '${shape.name} ${state.name} $size',
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('External audio decays after interruption and demo can resume', (
    tester,
  ) async {
    final c = MurmurController(
      vsync: const TestVSync(),
      style: const MurmurStyle(smoothing: 0),
    );
    c.useExternalAudio();
    await tester.pump();
    c.addFrame(AudioFrame(volume: 0.5, bands: List.filled(24, 0.5)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.rawVolume, 0.5);
    expect(c.volume, closeTo(0.75, 0.001));
    // The controller caps each tick at 100 ms, so advance several real frames.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(c.rawVolume, 0);
    expect(c.volume, 0);
    c.useDemo();
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.isDemo, isTrue);
    expect(c.rawVolume, greaterThan(0));
    c.setPaused(true);
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.rawVolume, 0);
    c.dispose();
  });
  testWidgets('A springy style overshoots a sudden sound, then settles on it', (
    tester,
  ) async {
    final c = MurmurController(
      vsync: const TestVSync(),
      style: const MurmurStyle(sensitivity: 1, bounce: 0.6),
    );
    c.useExternalAudio();
    var peak = 0.0;
    for (var i = 0; i < 90; i++) {
      c.addFrame(AudioFrame(volume: 0.5, bands: List.filled(24, 0.5)));
      await tester.pump(const Duration(milliseconds: 16));
      if (c.volume > peak) peak = c.volume;
    }
    expect(peak, greaterThan(0.55), reason: 'a spring goes past the level');
    expect(c.volume, closeTo(0.5, 0.02), reason: 'and comes to rest on it');
    expect(c.bands.first, closeTo(0.5, 0.02));
    c.dispose();
  });
  testWidgets('A change of state is eased in, not switched to', (tester) async {
    final c = MurmurController(vsync: const TestVSync());
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.thinkingMix, 0);
    c.state = AgentState.thinking;
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.thinkingMix, inExclusiveRange(0, 0.3));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(c.thinkingMix, greaterThan(0.95));
    c.state = AgentState.idle;
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.idleMix, inExclusiveRange(0, 0.3));
    expect(c.thinkingMix, greaterThan(0.7));
    c.dispose();
  });
  testWidgets(
    'A springy level falls back without dropping below and stopping dead',
    (tester) async {
      final c = MurmurController(
        vsync: const TestVSync(),
        style: const MurmurStyle(sensitivity: 1, bounce: 0.6),
      );
      c.useExternalAudio();
      for (var i = 0; i < 60; i++) {
        c.addFrame(AudioFrame(volume: 0.6, bands: List.filled(24, 0.6)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // The sound stops: after a quarter second the level is let go.
      var previous = c.volume, steepest = 0.0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          c.volume,
          lessThanOrEqualTo(previous + 1e-9),
          reason: 'no bounce on the way down',
        );
        steepest = previous - c.volume > steepest
            ? previous - c.volume
            : steepest;
        previous = c.volume;
      }
      expect(steepest, lessThan(0.08), reason: 'no frame drops it by much');
      expect(c.volume, lessThan(0.05));
      c.dispose();
    },
  );
  testWidgets('Semantics report state changes for a reusable indicator', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final c = MurmurController(vsync: const TestVSync());
    await tester.pumpWidget(MaterialApp(home: Murmur(controller: c)));
    expect(find.bySemanticsLabel('Aurora orb, listening'), findsOneWidget);
    c.state = AgentState.thinking;
    await tester.pump();
    expect(find.bySemanticsLabel('Aurora orb, thinking'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    semantics.dispose();
  });
  testWidgets('Water ripples respond to audio and settle during silence', (
    tester,
  ) async {
    final c = MurmurController(
      vsync: const TestVSync(),
      style: const MurmurStyle(smoothing: 0),
    );
    c.useExternalAudio();
    await tester.pump();
    expect(c.ripples, isEmpty);
    c.addFrame(AudioFrame(volume: 0.7, bands: List.filled(24, 0.7)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.ripples, isNotEmpty);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(c.ripples, isEmpty);
    c.state = AgentState.idle;
    c.addFrame(AudioFrame(volume: 1, bands: List.filled(24, 1)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.ripples, isEmpty);
    c.dispose();
  });

  testWidgets(
    'Three determinate shapes render exact progress without a ticker',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final shape in MurmurLoading.supportedShapes) {
        for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          for (final size in [const Size(100, 70), const Size(700, 400)]) {
            await tester.pumpWidget(
              MaterialApp(
                home: Center(
                  child: MurmurLoading(
                    progress: progress,
                    shape: shape,
                    size: size,
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(seconds: 1));
            expect(
              tester.takeException(),
              isNull,
              reason: '${shape.name} $progress $size',
            );
            expect(
              tester.getSemantics(find.bySemanticsLabel('Loading')).value,
              '${(progress * 100).floor()}%',
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );
}
