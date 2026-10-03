# Murmur Studio

A playground for the Murmur indicators. It shows each voice-reactive and
determinate indicator, with controls for the simulated voice agent and live
microphone input.

From the package root, generate the platform folders once, then run the app:

```sh
dart tool/bootstrap.dart
cd example && flutter run
```

Two minimal examples sit alongside the studio:

- `lib/minimal.dart`: one indicator, driven by the built-in demo signal.
- `lib/microphone.dart`: one indicator that reacts to the microphone.

Run one with `flutter run -t lib/minimal.dart` or `flutter run -t lib/microphone.dart`.
