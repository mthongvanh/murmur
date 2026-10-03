import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'controller.dart';
import 'models.dart';

/// Native Canvas indicator. Share one controller across previews to avoid
/// independent clocks; dispose that controller in the owning screen.
class VoiceIndicator extends StatefulWidget {
  /// Creates an indicator that draws [controller]'s signal as [shape].
  const VoiceIndicator({
    super.key,
    required this.controller,
    this.shape = VoiceShape.auroraOrb,
    this.style,
    this.size = const Size(320, 240),
    this.thumbnail = false,
  });

  /// Supplies the clock, the signal, and the agent state.
  final VoiceController controller;

  /// Which design to draw.
  final VoiceShape shape;

  /// Overrides the controller's [VoiceController.style] for this indicator.
  final VoiceStyle? style;

  /// The size to paint at.
  final Size size;

  /// Draws a simpler version without glow, for small previews.
  final bool thumbnail;

  @override
  State<VoiceIndicator> createState() => _VoiceIndicatorState();
}

class _VoiceIndicatorState extends State<VoiceIndicator> {
  late AgentState _state;
  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    widget.controller.addListener(_updateSemantics);
  }

  void _updateSemantics() {
    if (_state != widget.controller.state && mounted) {
      setState(() {
        _state = widget.controller.state;
      });
    }
  }

  @override
  void didUpdateWidget(VoiceIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateSemantics);
      _state = widget.controller.state;
      widget.controller.addListener(_updateSemantics);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateSemantics);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.thumbnail
        ? widget.shape.label
        : '${widget.shape.label}, ${_state.name}',
    image: true,
    child: RepaintBoundary(
      child: CustomPaint(
        size: widget.size,
        painter: _VoicePainter(
          controller: widget.controller,
          shape: widget.shape,
          style: widget.style,
          thumbnail: widget.thumbnail,
          reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
        ),
      ),
    ),
  );
}

class _VoicePainter extends CustomPainter {
  _VoicePainter({
    required this.controller,
    required this.shape,
    required this.style,
    required this.thumbnail,
    required this.reduceMotion,
  }) : super(repaint: controller);
  final VoiceController controller;
  final VoiceShape shape;
  final VoiceStyle? style;
  final bool thumbnail, reduceMotion;
  static const tau = math.pi * 2;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final settings = style ?? controller.style;
    final color = settings.color;
    final t = reduceMotion ? 0.0 : controller.time;
    // A state's look is blended in, not switched to: the controller eases
    // each state's weight, so a change of state never jumps a frame.
    final thinking = controller.thinkingMix;
    final quiet = 1 - 0.93 * controller.idleMix;
    double lerp(double a, double b) => a + (b - a) * thinking;
    final amp = math.max(
      settings.rest,
      lerp(controller.volume, 0.12 + 0.1 * math.sin(t * 2)) * quiet,
    );
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * (thumbnail ? 0.31 : 0.235) * settings.scale;
    final bands = controller.bands;
    double frequency(double fraction) {
      final band = bands[(fraction * (bands.length - 1)).round()];
      return math.max(
        settings.rest,
        lerp(band, 0.12 + 0.1 * math.sin(t * 2 + fraction * 8)) * quiet,
      );
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void opacity(double a) {
      paint.color = color.withValues(alpha: a.clamp(0.0, 1.0).toDouble());
    }

    void fillCircle(Offset p, double radius) {
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(p, radius, paint);
      paint.style = PaintingStyle.stroke;
    }

    void capsule(Rect rect) {
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2)),
        paint,
      );
      paint.style = PaintingStyle.stroke;
    }

    Offset polar(double radius, double angle) =>
        center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (settings.glow && !thumbnail) {
      final rect = Rect.fromCircle(center: center, radius: r * 1.7);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.07 + amp * 0.08),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect);
      canvas.drawCircle(center, r * 1.7, glow);
    }
    switch (shape) {
      case VoiceShape.auroraOrb:
        final rr = r * (0.78 + amp * 0.23);
        // The highlight is a focal point up and to the left, while the fade
        // ends on the disc's own edge, so the glow has no rim on any side.
        final rect = Rect.fromCircle(center: center, radius: rr * 1.24);
        canvas.drawCircle(
          center,
          rr * 1.24,
          Paint()
            ..shader = RadialGradient(
              focal: const Alignment(-0.25, -0.3),
              colors: [
                color.withValues(alpha: 0.56),
                color.withValues(alpha: 0.19),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 0.5, 1],
            ).createShader(rect),
        );
        final rows = thumbnail ? 18 : 34, steps = thumbnail ? 50 : 100;
        for (var j = 0; j < rows; j++) {
          final latitude = j / (rows - 1) * math.pi;
          final rad = rr * math.sin(latitude),
              yy = center.dy + rr * math.cos(latitude);
          opacity(0.18 + 0.55 * math.sin(latitude));
          paint.strokeWidth = thumbnail ? 0.55 : 0.9;
          final path = Path();
          for (var k = 0; k <= steps; k++) {
            final a = k / steps * tau;
            final ripple =
                1 +
                amp * 0.18 * math.sin(a * 5 + t * 2 + j * 0.28) +
                0.03 * math.sin(a * 3 - t);
            final x = center.dx + math.cos(a) * rad * ripple;
            final y =
                yy +
                math.sin(a) * rad * 0.19 +
                amp * rr * 0.09 * math.sin(a * 4 + t + j * 0.2);
            if (k == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, paint);
        }
      case VoiceShape.frequencyBars:
        final n = thumbnail ? 11 : 25, width = r * 2.1 / (thumbnail ? 11 : 25);
        for (var i = 0; i < n; i++) {
          final edge = math.sin((i + 0.5) / n * math.pi);
          final height = math.max(
            4.0,
            (0.08 + amp * 0.3 * edge + frequency(i / n) * 1.2 * edge) * r * 1.9,
          );
          opacity(0.5 + edge * 0.5);
          capsule(
            Rect.fromLTWH(
              center.dx + (i - n / 2) * width,
              center.dy - height / 2,
              width * 0.55,
              height,
            ),
          );
        }
      case VoiceShape.rippleRings:
        for (var j = 0; j < 5; j++) {
          final phase = (t * 0.22 + j / 5) % 1;
          opacity((1 - phase) * 0.85);
          paint.strokeWidth = thumbnail ? 1 : 1.5;
          canvas.drawCircle(
            center,
            r * (0.3 + phase * 0.85 + amp * 0.15),
            paint,
          );
        }
        opacity(1);
        fillCircle(center, r * (0.09 + amp * 0.04));
      case VoiceShape.waveform:
      case VoiceShape.voiceRibbon:
        final ribbon = shape == VoiceShape.voiceRibbon;
        final width = r * (thumbnail ? 3.0 : 4.1);
        final samples = controller.waveform;
        for (var j = 0; j < (ribbon ? 5 : 3); j++) {
          opacity(ribbon ? 0.18 + j * 0.15 : 1 - j * 0.28);
          paint.strokeWidth = thumbnail ? 1.2 : (ribbon ? 2 : 1.8);
          final path = Path();
          for (var i = 0; i <= 160; i++) {
            final x = i / 160,
                env = math.pow(math.sin(x * math.pi), 2).toDouble();
            final wave = ribbon
                ? math.sin(x * 10 - t * 2 + j * 0.5) +
                      0.3 * math.sin(x * 20 + t)
                : samples.isNotEmpty && controller.state != AgentState.thinking
                ? samples[math.min(
                        samples.length - 1,
                        (x * (samples.length - 1)).floor(),
                      )] *
                      2
                : math.sin(x * 32 - t * 3 + j * 0.6) *
                      (0.4 + 0.6 * math.sin(x * 7 + t));
            final px = center.dx - width / 2 + x * width;
            final py = center.dy + wave * env * r * (0.08 + amp * 0.66);
            if (i == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
          }
          canvas.drawPath(path, paint);
        }
      case VoiceShape.particleCloud:
        final count = thumbnail ? 70 : 180;
        for (var i = 0; i < count; i++) {
          final a = i * 2.39996 + t * 0.13;
          final rad = r * math.sqrt((i + 0.5) / count) * (0.6 + amp * 0.55);
          opacity(0.25 + 0.65 * (0.5 + 0.5 * math.sin(i + t)));
          fillCircle(
            center +
                Offset(
                  math.cos(a) * rad * (1 + 0.1 * math.sin(t + i)),
                  math.sin(a) * rad * 0.85,
                ),
            thumbnail ? 1 : 1 + amp * 1.8,
          );
        }
      case VoiceShape.spectrumHalo:
        final count = thumbnail ? 36 : 72;
        for (var i = 0; i < count; i++) {
          final a = i / count * tau - math.pi / 2, band = frequency(i / count);
          final inner = r * 0.65,
              outer = inner + r * (0.07 + amp * 0.2 + band * 0.7);
          paint.strokeWidth = thumbnail ? 1.3 : 2.4;
          opacity(0.45 + 0.55 * band);
          canvas.drawLine(polar(inner, a), polar(outer, a), paint);
        }
        opacity(0.25);
        paint.strokeWidth = 1;
        canvas.drawCircle(center, r * 0.52, paint);
      case VoiceShape.dotMatrix:
        final columns = thumbnail ? 11 : 17,
            spacing = r * 2.7 / (thumbnail ? 11 : 17);
        for (var x = 0; x < columns; x++) {
          final active = math.max(
            1,
            ((0.15 + frequency(x / columns)) * 7).round(),
          );
          for (var y = 0; y < 7; y++) {
            final on = (y - 3).abs() < active / 2;
            opacity(on ? 0.9 : 0.12);
            fillCircle(
              center +
                  Offset((x - (columns - 1) / 2) * spacing, (y - 3) * spacing),
              spacing * (on ? 0.23 : 0.17),
            );
          }
        }
      case VoiceShape.radialSpokes:
        final count = thumbnail ? 12 : 24;
        paint.strokeWidth = thumbnail ? 2 : 4;
        for (var i = 0; i < count; i++) {
          final a = i / count * tau + t * 0.12, band = frequency(i / count);
          final length = r * (0.23 + amp * 0.3 + 0.65 * band);
          opacity(0.45 + 0.5 * band);
          canvas.drawLine(
            polar(r * 0.18, a),
            polar(r * 0.18 + length, a),
            paint,
          );
        }
      case VoiceShape.orbitTrails:
        for (var j = 0; j < 3; j++) {
          final tilt = t * 0.18 + j * math.pi / 3;
          final rx = r * (0.85 + amp * 0.16), ry = r * (0.26 + amp * 0.25);
          opacity(0.5);
          paint.strokeWidth = thumbnail ? 1 : 1.4;
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(tilt);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
            paint,
          );
          canvas.restore();
          final a = t * (0.8 + j * 0.2) + j * 2;
          final x = rx * math.cos(a), y = ry * math.sin(a);
          opacity(1);
          fillCircle(
            center +
                Offset(
                  x * math.cos(tilt) - y * math.sin(tilt),
                  x * math.sin(tilt) + y * math.cos(tilt),
                ),
            thumbnail ? 2 : 3 + amp * 3,
          );
        }
        opacity(0.7);
        fillCircle(center, r * (0.05 + amp * 0.08));
      case VoiceShape.pulseCapsule:
        final width = r * (0.55 + amp * 1.6), height = r * (0.6 + amp * 0.3);
        opacity(0.14);
        capsule(
          Rect.fromCenter(
            center: center,
            width: width + 16,
            height: height + 16,
          ),
        );
        opacity(0.85);
        capsule(Rect.fromCenter(center: center, width: width, height: height));
        final spacing = math.min(width / 8, r * 0.14);
        for (var i = 0; i < 5; i++) {
          final hh = height * (0.15 + frequency(i / 5) * 0.65);
          paint.color = const Color(0xFF172822);
          capsule(
            Rect.fromCenter(
              center: center + Offset((i - 2) * spacing, 0),
              width: spacing * 0.3,
              height: math.max(2.0, hh),
            ),
          );
        }
      case VoiceShape.contourBloom:
        final count = thumbnail ? 5 : 9;
        for (var j = 0; j < count; j++) {
          final base = r * (0.28 + j / count * 0.72);
          opacity(0.25 + j / count * 0.65);
          paint.strokeWidth = thumbnail ? 0.9 : 1.3;
          final path = Path();
          for (var k = 0; k <= 160; k++) {
            final a = k / 160 * tau;
            final radius =
                base *
                (1 +
                    (0.03 + amp * 0.17) * math.sin(a * 5 - t * 1.4 + j * 0.3) +
                    amp * 0.08 * math.cos(a * 3 + t));
            final p = polar(radius, a);
            if (k == 0) {
              path.moveTo(p.dx, p.dy);
            } else {
              path.lineTo(p.dx, p.dy);
            }
          }
          canvas.drawPath(path..close(), paint);
        }
      case VoiceShape.waterSurface:
        final sy = center.dy + r * 0.1, rx = r * 1.65, ry = r * 0.72;
        final pulses = controller.state == AgentState.idle || reduceMotion
            ? <RipplePulse>[]
            : controller.ripples
                  .where((p) => t - p.time >= 0 && t - p.time < 3.2)
                  .toList();
        ({double height, double energy}) sample(double rho) {
          var height = 0.0, energy = 0.0;
          for (final pulse in pulses) {
            final age = t - pulse.time, delta = rho - (0.045 + age * 0.28);
            final envelope =
                math.exp(-math.pow(delta / 0.06, 2)) *
                math.exp(-age * 0.45) *
                pulse.strength;
            height += math.cos(delta * 32) * envelope;
            energy += envelope;
          }
          return (height: height, energy: energy);
        }
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
                    color.withValues(alpha: 0.086),
                    color.withValues(alpha: 0),
                  ],
                ).createShader(
                  Rect.fromCircle(center: Offset(center.dx, sy), radius: rx),
                ),
        );
        final rows = thumbnail ? 17 : 32, steps = thumbnail ? 48 : 96;
        paint.strokeWidth = thumbnail ? 0.55 : 0.85;
        for (var j = 1; j <= rows; j++) {
          final rho = j / rows, wave = sample(rho);
          final path = Path();
          opacity(0.07 + 0.13 * (1 - rho) + math.min(0.62, wave.energy * 0.65));
          for (var k = 0; k <= steps; k++) {
            final a = k / steps * tau;
            final x = center.dx + math.cos(a) * rx * rho;
            final y = sy + math.sin(a) * ry * rho - r * wave.height * 0.22;
            if (k == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, paint);
        }
        for (var j = 0; j < 12; j++) {
          final a = j / 12 * tau;
          opacity(0.07);
          paint.strokeWidth = thumbnail ? 0.4 : 0.6;
          final path = Path();
          for (var k = 0; k <= 60; k++) {
            final rho = k / 60, wave = sample(rho);
            final x = center.dx + math.cos(a) * rx * rho;
            final y = sy + math.sin(a) * ry * rho - r * wave.height * 0.22;
            if (k == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, paint);
        }
        for (final pulse in pulses) {
          final age = t - pulse.time, rho = 0.045 + age * 0.28;
          final wave = sample(rho);
          opacity((1 - age / 3.2) * (0.25 + pulse.strength * 0.65));
          paint.strokeWidth = thumbnail ? 0.8 : 1.2 + pulse.strength * 0.6;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(center.dx, sy - r * wave.height * 0.22),
              width: rx * rho * 2,
              height: ry * rho * 2,
            ),
            paint,
          );
        }
      case VoiceShape.foldedLight:
        const vertices = [
          [0.0, -1.0, 0.0],
          [-0.9, 0.6, 0.65],
          [0.9, 0.6, 0.65],
          [0.0, 0.6, -1.0],
        ];
        const edges = [
          [0, 1],
          [0, 2],
          [0, 3],
          [1, 2],
          [2, 3],
          [3, 1],
        ];
        for (var layer = 0; layer < 5; layer++) {
          final a = t * 0.3 + layer * 0.22, b = t * 0.17 + layer * 0.12;
          final scale = r * (0.65 + layer * 0.09 + amp * 0.2);
          final points = vertices.map((v) {
            final xx = v[0] * math.cos(a) + v[2] * math.sin(a);
            final zz = -v[0] * math.sin(a) + v[2] * math.cos(a);
            final yy = v[1] * math.cos(b) - zz * math.sin(b);
            final depth = v[1] * math.sin(b) + zz * math.cos(b);
            final lens = 2.8 / (2.8 - depth * 0.4);
            return Offset(
              center.dx + xx * scale * lens,
              center.dy + yy * scale * lens,
            );
          }).toList();
          opacity(0.18 + layer * 0.13);
          paint.strokeWidth = thumbnail ? 0.7 : 1.15;
          for (final edge in edges) {
            canvas.drawLine(points[edge[0]], points[edge[1]], paint);
          }
        }
      case VoiceShape.gravityWell:
        final lines = thumbnail ? 9 : 17;
        for (var j = 0; j < lines; j++) {
          final base = (j - (lines - 1) / 2) / (lines / 2);
          final path = Path();
          opacity(0.2 + 0.65 * (1 - base.abs()));
          paint.strokeWidth = thumbnail ? 0.65 : 1.1;
          for (var k = 0; k <= 100; k++) {
            final u = k / 100, x = (u - 0.5) * r * 3.2;
            final envelope = math.exp(-math.pow(x / (r * 0.5), 2));
            final pinch = base * (1 - envelope * (0.5 + amp * 0.4));
            final y =
                center.dy +
                pinch * r * 0.88 +
                math.sin(u * tau + t * 1.5 + base) * envelope * r * 0.1 * amp;
            if (k == 0) {
              path.moveTo(center.dx + x, y);
            } else {
              path.lineTo(center.dx + x, y);
            }
          }
          canvas.drawPath(path, paint);
        }
        for (var j = 0; j < 6; j++) {
          final q = (t * 0.17 + j / 6) % 1, x = (q - 0.5) * r * 3.2;
          final base = math.sin(j * 2.4) * 0.8;
          final envelope = math.exp(-math.pow(x / (r * 0.5), 2));
          opacity(0.6);
          fillCircle(
            Offset(
              center.dx + x,
              center.dy + base * (1 - envelope * (0.5 + amp * 0.4)) * r * 0.88,
            ),
            thumbnail ? 1 : 1.5 + amp,
          );
        }
      case VoiceShape.phaseWeave:
        for (var j = 0; j < 4; j++) {
          final phase = t * 0.25 + j * 0.19;
          opacity(0.25 + j * 0.16);
          paint.strokeWidth = thumbnail ? 0.75 : 1.3;
          final path = Path();
          for (var k = 0; k <= 400; k++) {
            final a = k / 400 * tau;
            final x = math.sin(a * 3 + phase) * r * (0.8 + amp * 0.22);
            final y = math.sin(a * 2 - phase) * r * (0.55 + amp * 0.18);
            final rotation = t * 0.08;
            final xx =
                center.dx + x * math.cos(rotation) - y * math.sin(rotation);
            final yy =
                center.dy + x * math.sin(rotation) + y * math.cos(rotation);
            if (k == 0) {
              path.moveTo(xx, yy);
            } else {
              path.lineTo(xx, yy);
            }
          }
          canvas.drawPath(path, paint);
        }
      case VoiceShape.inkEclipse:
        final rr = r * (0.83 + amp * 0.12);
        final outer = Path()
          ..addOval(Rect.fromCircle(center: center, radius: rr * 1.25));
        final dx = r * (0.28 + 0.13 * math.sin(t * 0.8) + amp * 0.1);
        final dy = r * 0.12 * math.cos(t * 0.6);
        final inner = Path()
          ..addOval(
            Rect.fromCircle(center: center + Offset(dx, dy), radius: rr * 0.93),
          );
        final cutout = Path.combine(PathOperation.difference, outer, inner);
        canvas.drawPath(
          cutout,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.2, -0.2),
              colors: [
                color.withValues(alpha: 0.87),
                color.withValues(alpha: 0.27),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 0.7, 1],
            ).createShader(Rect.fromCircle(center: center, radius: rr * 1.25)),
        );
        opacity(0.45);
        paint.strokeWidth = thumbnail ? 0.75 : 1;
        for (var j = 0; j < 3; j++) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(t * 0.12);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: rr * (1.05 + j * 0.08) * 2,
              height: rr * (0.5 + j * 0.05) * 2,
            ),
            paint,
          );
          canvas.restore();
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VoicePainter old) =>
      old.controller != controller ||
      old.shape != shape ||
      old.style != style ||
      old.thumbnail != thumbnail ||
      old.reduceMotion != reduceMotion;
}
