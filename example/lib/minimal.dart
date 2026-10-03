import 'package:flutter/material.dart';
import 'package:murmur/murmur.dart';

/// One indicator, driven by the controller's built-in demo signal.
/// Run from the example folder: flutter run -t lib/minimal.dart
void main() => runApp(const MaterialApp(home: MinimalExample()));

class MinimalExample extends StatefulWidget {
  const MinimalExample({super.key});

  @override
  State<MinimalExample> createState() => _MinimalExampleState();
}

class _MinimalExampleState extends State<MinimalExample>
    with SingleTickerProviderStateMixin {
  late final MurmurController controller;

  @override
  void initState() {
    super.initState();
    controller = MurmurController(vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF171B1B),
    body: Center(child: Murmur(controller: controller)),
  );
}
