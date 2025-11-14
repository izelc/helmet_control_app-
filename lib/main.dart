import 'package:flutter/material.dart';

import 'services/helmet_service.dart';
import 'services/activity_logger.dart';
import 'controllers/helmet_controller.dart';
import 'ui/helmet_app.dart';

void main() {
  final service = WebSocketHelmetService(
    // Android emulator için:
    url: 'ws://10.0.2.2:8000',
    // macOS / web için:
    // url: 'ws://localhost:8000',
  );

  final logger = NodeActivityLogger(
    // Android emulator -> host
    baseUrl: 'http://10.0.2.2:3000',
    // macOS / web:
    // baseUrl: 'http://localhost:3000',
  );

  final controller = HelmetController(service: service, logger: logger);

  runApp(HelmetApp(controller: controller));
}
