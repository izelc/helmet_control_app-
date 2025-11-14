import 'dart:convert';

import 'package:web_socket_channel/io.dart';

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
