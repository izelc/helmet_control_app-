import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class ActivityLogger {
  Future<void> logCommand({
    required String user,
    required String command,
    required DateTime timestamp,
  });
}

class NodeActivityLogger implements ActivityLogger {
  final String baseUrl;
  final http.Client _client;

  NodeActivityLogger({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<void> logCommand({
    required String user,
    required String command,
    required DateTime timestamp,
  }) async {
    final uri = Uri.parse('$baseUrl/event');

    final body = {
      'user': user,
      'command': command,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode >= 400) {
        // logging hataları app'i bozmasın diye sadece sessiz geçiyoruz
      }
    } catch (e) {
      // Node server kapalıysa vs. burada da app crash etmesin
    }
  }
}
