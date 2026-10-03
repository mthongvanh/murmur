import 'package:flutter/painting.dart';

enum AgentState { idle, listening, thinking, speaking }

enum VoiceShape {
  auroraOrb('Aurora orb', 'Organic · immersive'),
  frequencyBars('Frequency bars', 'Rhythmic · precise'),
  rippleRings('Ripple rings', 'Calm · expansive'),
  waveform('Waveform', 'Familiar · expressive'),
  particleCloud('Particle cloud', 'Playful · ambient'),
  voiceRibbon('Voice ribbon', 'Fluid · continuous'),
  spectrumHalo('Spectrum halo', 'Circular · detailed'),
  dotMatrix('Dot matrix', 'Digital · tactile'),
  radialSpokes('Radial spokes', 'Bold · energetic'),
  orbitTrails('Orbit trails', 'Spatial · flowing'),
  pulseCapsule('Pulse capsule', 'Minimal · focused'),
  contourBloom('Contour bloom', 'Layered · organic'),
  waterSurface('Water surface', 'Rippling · luminous'),
  foldedLight('Folded light', 'Angular · prismatic'),
  gravityWell('Gravity well', 'Warped · magnetic'),
  phaseWeave('Phase weave', 'Entangled · continuous'),
  inkEclipse('Ink eclipse', 'Negative · atmospheric');

  @Deprecated('Use waterSurface; this indicator now renders water ripples.')
  static const VoiceShape auroraDrop = VoiceShape.waterSurface;

  const VoiceShape(this.label, this.description);
  final String label;
  final String description;
}

/// Immutable rendering settings. Audio capture is independent of appearance.
class VoiceStyle {
  const VoiceStyle({
    this.color = const Color(0xFFA4F5CE),
    this.scale = 1,
    this.sensitivity = 1.5,
    this.smoothing = 0.7,
    this.glow = true,
    this.bounce = 0,
    this.rest = 0,
  }) : assert(scale > 0),
       assert(sensitivity > 0),
       assert(smoothing >= 0 && smoothing <= 0.95),
       assert(bounce >= 0 && bounce < 1),
       assert(rest >= 0 && rest <= 1);

  final Color color;
  final double scale;
  final double sensitivity;

  /// Fraction retained per 60 Hz frame. Zero means immediate response.
  final double smoothing;
  final bool glow;

  /// Zero eases toward each level ([smoothing]). Above zero, the indicator
  /// follows the sound on a spring instead, overshooting and settling back:
  /// the higher, the springier. [smoothing] then sets how quick the spring
  /// is, a stiffer one for less.
  final double bounce;

  /// The level shown at silence, 0 to 1: the indicator never draws lower.
  /// Zero lets it fall to its smallest.
  final double rest;

  VoiceStyle copyWith({
    Color? color,
    double? scale,
    double? sensitivity,
    double? smoothing,
    bool? glow,
    double? bounce,
    double? rest,
  }) => VoiceStyle(
    color: color ?? this.color,
    scale: scale ?? this.scale,
    sensitivity: sensitivity ?? this.sensitivity,
    smoothing: smoothing ?? this.smoothing,
    glow: glow ?? this.glow,
    bounce: bounce ?? this.bounce,
    rest: rest ?? this.rest,
  );
}
