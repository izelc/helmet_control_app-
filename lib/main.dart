import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  final service = WebSocketHelmetService(
    // Android emulator için:
    url: 'ws://10.0.2.2:8000',
    // Eğer macOS / web’de çalıştırırsan:
    // url: 'ws://localhost:8000',
  );
  final controller = HelmetController(service: service);

  runApp(HelmetApp(controller: controller));
}

enum ConnectionStatus { disconnected, pairing, connected, error }

enum HelmetCommand { pair, start, pause, stop, cont }

extension HelmetCommandName on HelmetCommand {
  String get name {
    switch (this) {
      case HelmetCommand.pair:
        return 'pair';
      case HelmetCommand.start:
        return 'start';
      case HelmetCommand.pause:
        return 'pause';
      case HelmetCommand.stop:
        return 'stop';
      case HelmetCommand.cont:
        return 'continue';
    }
  }
}

abstract class HelmetService {
  Future<void> connect();
  Future<void> sendCommand(HelmetCommand command);
  Stream<String> get messages;
  Future<void> dispose();
}

class WebSocketHelmetService implements HelmetService {
  final String url;
  IOWebSocketChannel? _channel;

  WebSocketHelmetService({required this.url});

  @override
  Future<void> connect() async {
    _channel ??= IOWebSocketChannel.connect(Uri.parse(url));
  }

  @override
  Future<void> sendCommand(HelmetCommand command) async {
    if (_channel == null) {
      throw Exception('Not connected');
    }
    final payload = jsonEncode({'command': command.name});
    _channel!.sink.add(payload);
  }

  @override
  Stream<String> get messages =>
      _channel?.stream.map((e) => e.toString()) ?? const Stream.empty();

  @override
  Future<void> dispose() async {
    await _channel?.sink.close();
    _channel = null;
  }
}

class HelmetController extends ChangeNotifier {
  final HelmetService service;

  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  String lastCommand = 'none';
  String lastStatusMessage = 'Not connected';
  bool isRunning = false;
  bool isPaused = false;

  StreamSubscription<String>? _subscription;
  final Map<String, Completer<void>> _pendingCommands = {};

  HelmetController({required this.service});

  Future<void> init() async {
    try {
      await service.connect();
      _subscription = service.messages.listen(
        _handleMessage,
        onError: (e) {
          connectionStatus = ConnectionStatus.error;
          lastStatusMessage = 'Error: $e';
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (e) {
      connectionStatus = ConnectionStatus.error;
      lastStatusMessage = 'Connection failed: $e';
      notifyListeners();
    }
  }

  void _handleMessage(String raw) {
    try {
      final data = jsonDecode(raw);

      // simulator.py: {"error": "..."} olabilir
      final error = data['error'] as String?;
      if (error != null) {
        lastStatusMessage = 'Device error: $error';
        notifyListeners();
        return;
      }

      // simulator.py: {"status": "connected" | "start" | "pause" | ...}
      final status = data['status'] as String?;
      if (status == null) return;

      lastStatusMessage = 'Device status: $status';

      switch (status) {
        case 'connected':
          connectionStatus = ConnectionStatus.connected;
          break;
        case 'start':
          isRunning = true;
          isPaused = false;
          break;
        case 'pause':
          isPaused = true;
          break;
        case 'continue':
          isPaused = false;
          isRunning = true;
          break;
        case 'stop':
          isRunning = false;
          isPaused = false;
          break;
        case 'not_connected':
          connectionStatus = ConnectionStatus.error;
          break;
        case 'not_running':
        case 'not_paused':
          // istersen bunlar için özel UI durumu gösterirsin
          break;
      }

      // Retry mekanizması için: beklediğimiz status geldiyse completer'ı tamamla
      final completer = _pendingCommands.remove(status);
      completer?.complete();

      notifyListeners();
    } catch (_) {}
  }

  Future<void> pair() async {
    connectionStatus = ConnectionStatus.pairing;
    lastStatusMessage = 'Pairing...';
    notifyListeners();

    try {
      await _sendWithRetry(HelmetCommand.pair);
      lastCommand = 'pair';
    } on TimeoutException {
      connectionStatus = ConnectionStatus.error;
      lastStatusMessage = 'Pair command timed out';
    } catch (e) {
      connectionStatus = ConnectionStatus.error;
      lastStatusMessage = 'Pair error: $e';
    }

    notifyListeners();
  }

  Future<void> start() async {
    if (connectionStatus != ConnectionStatus.connected) return;

    try {
      await _sendWithRetry(HelmetCommand.start);
      lastCommand = 'start';
    } on TimeoutException {
      lastStatusMessage = 'Start command timed out';
    } catch (e) {
      lastStatusMessage = 'Start error: $e';
    }

    notifyListeners();
  }

  Future<void> pause() async {
    if (!isRunning || isPaused) return;

    try {
      await _sendWithRetry(HelmetCommand.pause);
      lastCommand = 'pause';
    } on TimeoutException {
      lastStatusMessage = 'Pause command timed out';
    } catch (e) {
      lastStatusMessage = 'Pause error: $e';
    }

    notifyListeners();
  }

  Future<void> cont() async {
    if (!isPaused) return;

    try {
      await _sendWithRetry(HelmetCommand.cont);
      lastCommand = 'continue';
    } on TimeoutException {
      lastStatusMessage = 'Continue command timed out';
    } catch (e) {
      lastStatusMessage = 'Continue error: $e';
    }

    notifyListeners();
  }

  Future<void> stop() async {
    if (!isRunning && !isPaused) return;

    try {
      await _sendWithRetry(HelmetCommand.stop);
      lastCommand = 'stop';
    } on TimeoutException {
      lastStatusMessage = 'Stop command timed out';
    } catch (e) {
      lastStatusMessage = 'Stop error: $e';
    }

    notifyListeners();
  }

  Future<void> _sendWithRetry(
    HelmetCommand command, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    int attempt = 0;

    // simulator.py tarafında hangi "status" ile cevap bekliyoruz?
    String expectedStatus;
    switch (command) {
      case HelmetCommand.pair:
        expectedStatus = 'connected'; // pair -> connected
        break;
      case HelmetCommand.cont:
        expectedStatus = 'continue';
        break;
      default:
        // start, pause, stop için status isimleri ile aynı
        expectedStatus = command.name;
        break;
    }

    while (attempt < maxRetries) {
      attempt++;

      final completer = Completer<void>();
      _pendingCommands[expectedStatus] = completer;

      await service.sendCommand(command);

      try {
        await completer.future.timeout(timeout);
        return;
      } on TimeoutException {
        _pendingCommands.remove(expectedStatus);
        if (attempt >= maxRetries) {
          lastStatusMessage =
              'Command ${command.name} failed after $attempt attempts';
          notifyListeners();
          rethrow;
        }
      }
    }
  }

  Future<void> disposeController() async {
    await _subscription?.cancel();
    await service.dispose();
  }
}

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
