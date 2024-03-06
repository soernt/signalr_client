import 'dart:async';

import 'package:logging/logging.dart';

typedef LogMessageDelegate = void Function(LogMessage);

class DelegatingLogSink {
  // Properties
  final LogMessageDelegate _logFunc;
  StreamSubscription<LogRecord>? _subscription;

  // Methods

  DelegatingLogSink(this._logFunc);

  void attachToLogger(Logger? logger) {
    assert(logger != null);

    _subscription = Logger.root.onRecord
        .listen(_logMessage, onDone: _handleOnDone, cancelOnError: true);
  }

  void dispose() {
    _subscription?.cancel();
  }

  void _handleOnDone() {
    _subscription = null;
  }

  void _logMessage(LogRecord event) {
    _logFunc(LogMessage(event.time, event.level, event.message));
  }
}

class LogMessage {
  // Properites
  final DateTime at;
  final Level level;
  String message;

  // Methods
  LogMessage(this.at, this.level, this.message);
}
