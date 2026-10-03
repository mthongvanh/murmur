import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/murmur.dart';

/// Run from the package root: flutter test tool/render_gifs.dart
/// Renders a looping GIF of every indicator into doc/gifs. Needs ffmpeg.
const size = Size(320, 240);
const pixelRatio = 1.0;
const fps = 20;
const frameTime = Duration(microseconds: 1000000 ~/ fps);
const stageColor = Color(0xFF171B1B);

void main() {
  testWidgets('Render indicator GIFs', (tester) async {
    final out = Directory('doc/gifs')..createSync(recursive: true);
    final temp = Directory.systemTemp.createTempSync('murmur-gifs-');
    final key = GlobalKey();
    Future<void> show(Widget indicator) => tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(color: stageColor, child: indicator),
          ),
        ),
      ),
    );
    try {
      for (final shape in MurmurShape.values) {
        final controller = MurmurController(vsync: const TestVSync());
        await show(Murmur(controller: controller, shape: shape, size: size));
        // Let the demo signal and smoothing settle before recording.
        for (var i = 0; i < 2 * fps; i++) {
          await tester.pump(frameTime);
        }
        final frames = await record(tester, key, temp, 4 * fps, (_) async {
          await tester.pump(frameTime);
        });
        await encode(tester, frames, '${out.path}/${snake(shape.name)}.gif');
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
      for (final shape in MurmurLoading.supportedShapes) {
        // Hold empty, fill over three seconds, then hold full.
        const hold = fps ~/ 2, fill = 3 * fps;
        final frames = await record(tester, key, temp, hold + fill + fps, (
          i,
        ) async {
          final t = ((i - hold) / fill).clamp(0.0, 1.0);
          await show(
            MurmurLoading(
              progress: Curves.easeInOut.transform(t),
              shape: shape,
              size: size,
            ),
          );
        });
        await encode(
          tester,
          frames,
          '${out.path}/loading_${snake(shape.name)}.gif',
        );
      }
    } finally {
      await tester.runAsync(() => temp.delete(recursive: true));
    }
  }, timeout: Timeout.none);
}

/// Captures [count] frames into a fresh folder, calling [advance] before
/// each one.
Future<Directory> record(
  WidgetTester tester,
  GlobalKey key,
  Directory temp,
  int count,
  Future<void> Function(int frame) advance,
) async {
  final dir = temp.createTempSync('frames-');
  for (var i = 0; i < count; i++) {
    await advance(i);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final name = i.toString().padLeft(3, '0');
      File(
        '${dir.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
  return dir;
}

/// Encodes the frames with a palette built from them, so the glow keeps its
/// gradients.
Future<void> encode(WidgetTester tester, Directory frames, String path) async {
  const palette =
      '[0]split[a][b];[a]palettegen=stats_mode=diff[p];'
      '[b][p]paletteuse=dither=bayer:bayer_scale=4';
  final result = await tester.runAsync(
    () => Process.run('ffmpeg', [
      '-y',
      '-v',
      'error',
      '-framerate',
      '$fps',
      '-i',
      '${frames.path}/%03d.png',
      '-filter_complex',
      palette,
      '-loop',
      '0',
      path,
    ]),
  );
  if (result!.exitCode != 0) {
    throw ProcessException('ffmpeg', [path], '${result.stderr}');
  }
  stdout.writeln('Wrote $path');
}

String snake(String name) =>
    name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
