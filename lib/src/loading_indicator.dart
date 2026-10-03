import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

/// Determinate progress drawn directly in Dart. [progress] is in [0, 1].
/// Rebuild with a new value from your task, upload, or download callback.
/// No clock, audio input, or controller is required.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    required this.progress,
    this.shape = VoiceShape.waterSurface,
    this.style = const VoiceStyle(),
    this.size = const Size(320, 240),
    this.thumbnail = false,
    this.semanticLabel = 'Loading',
  }) : assert(progress >= 0 && progress <= 1),
       assert(
         shape == VoiceShape.waterSurface ||
             shape == VoiceShape.spectrumHalo ||
             shape == VoiceShape.contourBloom,
       );
  static const supportedShapes = [
    VoiceShape.waterSurface,
    VoiceShape.spectrumHalo,
    VoiceShape.contourBloom,
  ];
  final double progress;
  final VoiceShape shape;
  final VoiceStyle style;
  final Size size;
  final bool thumbnail;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (!supportedShapes.contains(shape)) {
      throw ArgumentError.value(shape, 'shape', 'Unsupported loading shape');
    }
    final p = progress.isFinite ? progress.clamp(0.0, 1.0).toDouble() : 0.0;
    return Semantics(
      label: semanticLabel,
      value: '${(p * 100).floor()}%',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: size,
          painter: _LoadingPainter(
            progress: p,
            shape: shape,
            style: style,
            thumbnail: thumbnail,
          ),
        ),
      ),
    );
  }
}

class _LoadingPainter extends CustomPainter {
  _LoadingPainter({
    required this.progress,
    required this.shape,
    required this.style,
    required this.thumbnail,
  });
  final double progress;
  final VoiceShape shape;
  final VoiceStyle style;
  final bool thumbnail;
  static const tau = math.pi * 2;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * (thumbnail ? 0.31 : 0.235) * style.scale;
    final color = style.color, p = progress;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void opacity(double a) {
      paint.color = color.withValues(alpha: a.clamp(0.0, 1.0).toDouble());
    }

    Offset polar(double radius, double angle) =>
        center + Offset(math.cos(angle), math.sin(angle)) * radius;
    void stroke(Path path, {bool glow = false}) {
      if (glow && style.glow && !thumbnail) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = paint.strokeWidth + 2
            ..color = color.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawPath(path, paint);
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (shape == VoiceShape.spectrumHalo) {
      final n = thumbnail ? 36 : 72, inside = r * 0.67;
      for (var i = 0; i < n; i++) {
        final a = (i + 0.5) / n * tau - math.pi / 2;
        final filled = (p * n - i).clamp(0.0, 1.0).toDouble();
        final height =
            r * (0.12 + 0.14 * (0.5 + 0.5 * math.sin(i / n * math.pi * 6)));
        opacity(0.1 + 0.9 * filled);
        paint.strokeWidth = thumbnail ? 1.5 : 2.6;
        canvas.drawLine(polar(inside, a), polar(inside + height, a), paint);
      }
      opacity(0.12);
      paint.strokeWidth = thumbnail ? 0.65 : 1;
      canvas.drawCircle(center, r * 0.52, paint);
      if (p > 0) {
        opacity(0.75);
        paint.strokeWidth = thumbnail ? 1 : 1.6;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r * 0.52),
          -math.pi / 2,
          p * tau,
          false,
          paint,
        );
      }
    } else if (shape == VoiceShape.contourBloom) {
      final n = thumbnail ? 5 : 9;
      Path contour(double base, int layer, double portion) {
        final path = Path(), total = 160 * portion;
        for (var k = 0; k <= total.ceil(); k++) {
          final a = math.min(k.toDouble(), total) / 160 * tau - math.pi / 2;
          final radius =
              base *
              (1 +
                  0.13 * math.sin(a * 5 + layer * 0.3) +
                  0.05 * math.cos(a * 3));
          final point = polar(radius, a);
          if (k == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        return path;
      }

      for (var j = 0; j < n; j++) {
        final base = r * (0.28 + j / n * 0.72),
            filled = (p * n - j).clamp(0.0, 1.0).toDouble();
        opacity(0.1);
        paint.strokeWidth = thumbnail ? 0.9 : 1.3;
        stroke(contour(base, j, 1));
        if (filled > 0) {
          opacity(0.45 + j / n * 0.5);
          paint.strokeWidth = thumbnail ? 1 : 1.5;
          stroke(contour(base, j, filled));
        }
      }
    } else {
      final sy = center.dy + r * 0.1,
          rx = r * 1.65,
          ry = r * 0.72,
          front = math.sqrt(p);
      final rows = thumbnail ? 17 : 32;
      double lift(double rho) => p > 0 && p < 1
          ? math.exp(-math.pow((rho - front) / 0.05, 2)) * 0.14 * r
          : 0;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, sy),
          width: rx * 2,
          height: ry * 2,
        ),
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  color.withValues(alpha: 0.094),
                  color.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(center.dx, sy), radius: rx),
              ),
      );
      for (var j = 1; j <= rows; j++) {
        final rho = j / rows,
            loaded = ((front - j / rows) * rows + 1).clamp(0.0, 1.0).toDouble();
        opacity(0.08 + loaded * (0.25 + 0.2 * (1 - rho)));
        paint.strokeWidth = thumbnail ? 0.55 : 0.85;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, sy - lift(rho)),
            width: rx * rho * 2,
            height: ry * rho * 2,
          ),
          paint,
        );
      }
      for (var j = 0; j < 12; j++) {
        final a = j / 12 * tau;
        opacity(0.07);
        paint.strokeWidth = thumbnail ? 0.4 : 0.6;
        final path = Path();
        for (var k = 0; k <= 60; k++) {
          final rho = k / 60;
          final x = center.dx + math.cos(a) * rx * rho,
              y = sy + math.sin(a) * ry * rho - lift(rho);
          if (k == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, paint);
      }
      opacity(0.35);
      paint.strokeWidth = thumbnail ? 0.8 : 1;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, sy),
          width: rx * 2,
          height: ry * 2,
        ),
        paint,
      );
      if (p > 0) {
        opacity(0.9);
        paint.strokeWidth = thumbnail ? 1 : 1.5;
        final path = Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(center.dx, sy - lift(front)),
              width: rx * front * 2,
              height: ry * front * 2,
            ),
          );
        stroke(path, glow: true);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LoadingPainter old) =>
      old.progress != progress ||
      old.shape != shape ||
      old.style != style ||
      old.thumbnail != thumbnail;
}
