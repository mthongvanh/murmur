# Changelog

## 0.4.0

First release on pub.dev.

- **Breaking:** renamed the public classes to use the Murmur name:
  - `VoiceIndicator` is now `Murmur`.
  - `LoadingIndicator` is now `MurmurLoading`.
  - `VoiceController` is now `MurmurController`.
  - `VoiceStyle` is now `MurmurStyle`.
  - `VoiceShape` is now `MurmurShape`.
- **Breaking:** removed `VoiceShape.auroraDrop`; use `MurmurShape.waterSurface`.
- Documented the whole public API.
- Added install instructions, and a GIF gallery of every indicator, to the
  README. `tool/render_gifs.dart` regenerates the gallery
  (`flutter test tool/render_gifs.dart`, needs ffmpeg).
- Added an MIT license.
- `tool/bootstrap.dart` now generates platform folders with the bundle ID
  `com.thongvanh.michael.murmur`, replacing the `com.voicestudio` org.
  Existing platform folders are left as they are; delete them and re-run the
  script to pick up the new ID.
- Renamed the example app's root widget from `VoiceStudioApp` to
  `MurmurStudioApp`.
- Turned on strict analyzer checks and extra lint rules on top of
  `flutter_lints`, shared by the example, and formatted all code with
  `dart format`.

## 0.3.0

The first version tracked in this repository. Earlier versions predate it.

- `VoiceIndicator` with seventeen shapes: Aurora orb, Frequency bars, Ripple
  rings, Waveform, Particle cloud, Voice ribbon, Spectrum halo, Dot matrix,
  Radial spokes, Orbit trails, Pulse capsule, Contour bloom, Water surface,
  Folded light, Gravity well, Phase weave, and Ink eclipse.
- `LoadingIndicator` for determinate progress from 0.0 to 1.0, in Water
  surface, Spectrum halo, and Contour bloom styles.
- `VoiceController` with idle, listening, thinking, and speaking states, a
  built-in demo signal, and `addFrame` for audio from an existing voice agent.
- `VoiceStyle` for color, scale, glow, sensitivity, smoothing, `bounce` (a
  springy response that overshoots and settles), and `rest` (the level shown
  at silence).
- `Pcm16Analyzer` for mono PCM16 audio: RMS volume, 24 frequency bands, and
  waveform samples.
- `MicrophoneInput`, an optional microphone adapter built on `record`.
- `VoiceShape.auroraDrop` is deprecated; use `VoiceShape.waterSurface`.
