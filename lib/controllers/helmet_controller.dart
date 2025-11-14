import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../services/helmet_service.dart';
import '../services/activity_logger.dart';

enum ConnectionStatus { disconnected, pairing, connected, error }

class HelmetController extends ChangeNotifier {
  final HelmetService service;
  final ActivityLogger logger;

  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  String lastCommand = 'none';
  String lastStatusMessage = 'Not connected';
  bool isRunning = false;
  bool isPaused = false;

  StreamSubscription<String>? _subscription;
  final Map<String, Completer<void>> _pendingCommands = {};

  HelmetController({required this.service, required this.logger});

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

      final error = data['error'] as String?;
      if (error != null) {
        lastStatusMessage = 'Device error: $error';
        notifyListeners();
        return;
      }

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
          break;
      }

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
      await _log('pair');
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
      await _log('start');
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
      await _log('pause');
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
      await _log('continue');
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
      await _log('stop');
    } on TimeoutException {
      lastStatusMessage = 'Stop command timed out';
    } catch (e) {
      lastStatusMessage = 'Stop error: $e';
    }

    notifyListeners();
  }

  Future<void> _log(String command) async {
    await logger.logCommand(
      user: 'izel', // burayı istersen sonra dinamik yaparsın
      command: command,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _sendWithRetry(
    HelmetCommand command, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    int attempt = 0;

    String expectedStatus;
    switch (command) {
      case HelmetCommand.pair:
        expectedStatus = 'connected';
        break;
      case HelmetCommand.cont:
        expectedStatus = 'continue';
        break;
      default:
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
