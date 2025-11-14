import 'package:flutter/material.dart';

void main() {
  runApp(const HelmetApp());
}

class HelmetApp extends StatelessWidget {
  const HelmetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helmet Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HelmetControlPage(),
    );
  }
}

enum ConnectionStatus { disconnected, pairing, connected }

class HelmetControlPage extends StatefulWidget {
  const HelmetControlPage({super.key});

  @override
  State<HelmetControlPage> createState() => _HelmetControlPageState();
}

class _HelmetControlPageState extends State<HelmetControlPage> {
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String _lastCommand = 'None';

  void _setCommand(String command) {
    setState(() {
      _lastCommand = command;
    });
  }

  void _onPair() {
    setState(() {
      _connectionStatus = ConnectionStatus.pairing;
      _lastCommand = 'pair';
    });

    // Şimdilik "başarılı bağlandı" simülasyonu (Task #1 için)
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _connectionStatus = ConnectionStatus.connected;
      });
    });
  }

  void _onStart() {
    if (_connectionStatus != ConnectionStatus.connected) return;
    _setCommand('start');
  }

  void _onPause() {
    if (_connectionStatus != ConnectionStatus.connected) return;
    _setCommand('pause');
  }

  void _onStop() {
    if (_connectionStatus != ConnectionStatus.connected) return;
    _setCommand('stop');
  }

  String get _connectionText {
    switch (_connectionStatus) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.pairing:
        return 'Pairing...';
      case ConnectionStatus.connected:
        return 'Connected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionStatus == ConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Helmet Control')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status texts
            Text(
              'Connection status: $_connectionText',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Last command: $_lastCommand',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Pair button
            ElevatedButton(
              onPressed: _connectionStatus == ConnectionStatus.connected
                  ? null
                  : _onPair,
              child: const Text('Pair'),
            ),

            const SizedBox(height: 24),

            // Command buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: isConnected ? _onStart : null,
                  child: const Text('Start'),
                ),
                ElevatedButton(
                  onPressed: isConnected ? _onPause : null,
                  child: const Text('Pause'),
                ),
                ElevatedButton(
                  onPressed: isConnected ? _onStop : null,
                  child: const Text('Stop'),
                ),
              ],
            ),

            const Spacer(),

            // Küçük info alanı
            const Text(
              'Task #1 demo – UI + simple state\n(No real device communication yet)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
