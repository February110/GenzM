import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoggerService {
  void log(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[LOG] $message');
    if (error != null) {
      debugPrint('[ERROR] $error');
    }
    if (stackTrace != null) {
      debugPrint('[STACKTRACE] $stackTrace');
    }
  }
}

final loggerProvider = Provider<LoggerService>((_) => LoggerService());
