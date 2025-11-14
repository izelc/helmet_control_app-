import 'package:flutter/material.dart';
import '../controllers/helmet_controller.dart';

class HelmetApp extends StatelessWidget {
  final HelmetController controller;
  const HelmetApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helmet Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HelmetControlPage(controller: controller),
    );
  }
}

class HelmetControlPage extends StatefulWidget {
  final HelmetController controller;
  const HelmetControlPage({super.key, required this.controller});

  @override
  State<HelmetControlPage> createState() => _HelmetControlPageState();
}

class _HelmetControlPageState extends State<HelmetControlPage> {
  HelmetController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onControllerChanged);
    c.init();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_onControllerChanged);
    c.disposeController();
    super.dispose();
  }

  String get _connectionText {
    switch (c.connectionStatus) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.pairing:
        return 'Pairing...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = c.connectionStatus == ConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Helmet Control')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Connection status: $_connectionText',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Last command: ${c.lastCommand}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Status message: ${c.lastStatusMessage}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isConnected ? null : () => c.pair(),
              child: const Text('Pair'),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: isConnected ? () => c.start() : null,
                  child: const Text('Start'),
                ),
                ElevatedButton(
                  onPressed: c.isRunning && !c.isPaused
                      ? () => c.pause()
                      : null,
                  child: const Text('Pause'),
                ),
                ElevatedButton(
                  onPressed: c.isPaused ? () => c.cont() : null,
                  child: const Text('Continue'),
                ),
                ElevatedButton(
                  onPressed: (c.isRunning || c.isPaused)
                      ? () => c.stop()
                      : null,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Running: ${c.isRunning}, Paused: ${c.isPaused}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
