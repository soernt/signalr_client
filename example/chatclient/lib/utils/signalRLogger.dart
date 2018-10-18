
import 'package:signalr_client/signalr_client.dart';

typedef Log = void Function(LogMessage);

class SignalRLogger implements ILogger {
  // Properties
  final Log _logFunc;

  SignalRLogger(this._logFunc);

  // Methods
  @override
  void log(LogLevel logLevel, String message) {
    _logFunc(LogMessage(DateTime.now(), logLevel, message));
  }
}

class LogMessage {
  // Properites
  final DateTime at;
  final LogLevel level;
  String message;

  // Methods
  LogMessage(this.at, this.level, this.message);
}
