import 'dart:async';
import 'package:flutter/material.dart';
import 'package:murmur/murmur.dart';

/// One indicator that reacts to the microphone.
/// Run from the example folder: flutter run -t lib/microphone.dart
/// It needs microphone permission; dart tool/bootstrap.dart sets that up.
void main() => runApp(const MaterialApp(home: MicrophoneExample()));

class MicrophoneExample extends StatefulWidget {
  const MicrophoneExample({super.key});

  @override
  State<MicrophoneExample> createState() => _MicrophoneExampleState();
}

class _MicrophoneExampleState extends State<MicrophoneExample>
    with SingleTickerProviderStateMixin {
  late final MurmurController controller;
  late final MicrophoneInput microphone;
  String? error;

  @override
  void initState() {
    super.initState();
    // Show silence, not the demo signal, until the microphone starts.
    controller = MurmurController(vsync: this)..useExternalAudio();
    microphone = MicrophoneInput(controller);
    microphone.onError = (e) => setState(() => error = '$e');
    microphone.onEnded = () => setState(() => error = 'Microphone ended.');
  }

  Future<void> toggle() async {
    try {
      if (microphone.isActive) {
        await microphone.stop();
      } else {
        await microphone.start();
      }
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Stop the microphone before the controller it feeds.
    unawaited(microphone.dispose());
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF171B1B),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Murmur(controller: controller, shape: MurmurShape.frequencyBars),
          FilledButton.icon(
            onPressed: toggle,
            icon: Icon(microphone.isActive ? Icons.mic_off : Icons.mic),
            label: Text(microphone.isActive ? 'Stop' : 'Start microphone'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!, style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    ),
  );
}
