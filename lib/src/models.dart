import 'package:flutter/painting.dart';

/// What a voice agent is doing, which sets how the indicators move.
enum AgentState {
  /// Waiting. The indicators settle almost still.
  idle,

  /// Hearing the user. The indicators follow the audio level.
  listening,

  /// Working on a reply. The indicators move on their own.
  thinking,

  /// Replying. Drawn like [listening]; feed it the agent's playback audio.
  speaking,
}

/// The indicator designs. Each has a display [label] and a [description].
enum MurmurShape {
  /// A glowing orb of stacked lines that swells with sound.
  auroraOrb('Aurora orb', 'Organic · immersive'),

  /// A row of bars that rise and fall with the frequency bands.
  frequencyBars('Frequency bars', 'Rhythmic · precise'),

  /// Concentric rings that spread outward with sound.
  rippleRings('Ripple rings', 'Calm · expansive'),

  /// A line tracing the audio waveform.
  waveform('Waveform', 'Familiar · expressive'),

  /// A cloud of drifting particles.
  particleCloud('Particle cloud', 'Playful · ambient'),

  /// Layered lines that flow and swell with sound.
  voiceRibbon('Voice ribbon', 'Fluid · continuous'),

  /// Frequency bars arranged in a ring.
  spectrumHalo('Spectrum halo', 'Circular · detailed'),

  /// A grid of dots that light up with sound.
  dotMatrix('Dot matrix', 'Digital · tactile'),

  /// Spokes radiating from the center.
  radialSpokes('Radial spokes', 'Bold · energetic'),

  /// Points circling the center on tilted orbits.
  orbitTrails('Orbit trails', 'Spatial · flowing'),

  /// A single capsule that pulses with the level.
  pulseCapsule('Pulse capsule', 'Minimal · focused'),

  /// Nested organic contours that bloom outward.
  contourBloom('Contour bloom', 'Layered · organic'),

  /// A luminous water surface where sound sets off ripples.
  waterSurface('Water surface', 'Rippling · luminous'),

  /// Rotating, nested prismatic wireframes that expand with sound.
  foldedLight('Folded light', 'Angular · prismatic'),

  /// Flowing parallel lines that pinch into a magnetic center.
  gravityWell('Gravity well', 'Warped · magnetic'),

  /// Overlapping Lissajous paths that rotate and stretch with sound.
  phaseWeave('Phase weave', 'Entangled · continuous'),

  /// A translucent crescent with a moving negative-space center.
  inkEclipse('Ink eclipse', 'Negative · atmospheric');

  const MurmurShape(this.label, this.description);

  /// The display name, such as `Aurora orb`.
  final String label;

  /// A short character note, such as `Organic · immersive`.
  final String description;
}

/// Immutable rendering settings. Audio capture is independent of appearance.
class MurmurStyle {
  /// Creates a style. The defaults suit a dark background.
  const MurmurStyle({
    this.color = const Color(0xFFA4F5CE),
    this.secondaryColor,
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

  /// The color every indicator is drawn in.
  final Color color;

  /// A second color some shapes mix in. Null draws everything in [color], as
  /// before.
  ///
  /// [MurmurShape.particleCloud] draws about a third of its particles in it,
  /// and [MurmurShape.radialSpokes] draws the part of each spoke that sound
  /// pushes past its resting length in it. Other shapes ignore it.
  final Color? secondaryColor;

  /// Multiplies the indicator's drawn size. Must be above zero.
  final double scale;

  /// Multiplies the input level before it is drawn. Above 1 makes quiet
  /// sound look louder. Must be above zero.
  final double sensitivity;

  /// Fraction retained per 60 Hz frame. Zero means immediate response.
  final double smoothing;

  /// Whether to draw a soft glow around the lines.
  final bool glow;

  /// Zero eases toward each level ([smoothing]). Above zero, the indicator
  /// follows the sound on a spring instead, overshooting and settling back:
  /// the higher, the springier. [smoothing] then sets how quick the spring
  /// is, a stiffer one for less.
  final double bounce;

  /// The level shown at silence, 0 to 1: the indicator never draws lower.
  /// Zero lets it fall to its smallest.
  final double rest;

  /// A copy of this style with the given settings replaced.
  ///
  /// A null argument keeps the current value, so this can't clear
  /// [secondaryColor]: build a new [MurmurStyle] for that.
  MurmurStyle copyWith({
    Color? color,
    Color? secondaryColor,
    double? scale,
    double? sensitivity,
    double? smoothing,
    bool? glow,
    double? bounce,
    double? rest,
  }) => MurmurStyle(
    color: color ?? this.color,
    secondaryColor: secondaryColor ?? this.secondaryColor,
    scale: scale ?? this.scale,
    sensitivity: sensitivity ?? this.sensitivity,
    smoothing: smoothing ?? this.smoothing,
    glow: glow ?? this.glow,
    bounce: bounce ?? this.bounce,
    rest: rest ?? this.rest,
  );
}
