/// Voice-reactive and determinate loading indicators, painted in Dart.
///
/// Drive `VoiceIndicator`s from a shared `VoiceController`, fed by its demo
/// signal, your agent's audio through `Pcm16Analyzer`, or `MicrophoneInput`.
/// Show task progress with `LoadingIndicator`.
library;

export 'src/audio_analysis.dart' show AudioFrame, Pcm16Analyzer;
export 'src/controller.dart';
export 'src/indicator.dart';
export 'src/loading_indicator.dart';
export 'src/microphone_input.dart';
export 'src/models.dart';
