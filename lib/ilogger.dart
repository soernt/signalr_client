/// These values are designed to match the ASP.NET Log Levels since that's the pattern we're emulating here.
///
/// Indicates the severity of a log message.
///
///Log Levels are ordered in increasing severity. So `Debug` is more severe than `Trace`, etc.
///
enum LogLevel {
  ///Log level for very low severity diagnostic messages.
  Trace, // = 0
  ///Log level for low severity diagnostic messages.
  Debug, // = 1
  ///Log level for informational diagnostic messages.
  Information, // = 2
  ///Log level for diagnostic messages that indicate a non-fatal problem. */
  Warning, //= 3
  ///Log level for diagnostic messages that indicate a failure in the current operation. */
  Error, // = 4
  ///Log level for diagnostic messages that indicate a failure that will terminate the entire application. */
  Critical, // = 5
  ///The highest possible log level. Used when configuring logging to indicate that no log messages should be emitted. */
  None, //= 6
}

/// An abstraction that provides a sink for diagnostic messages.
abstract class ILogger {
  ///Called by the framework to emit a diagnostic message.
  ///
  /// [logLevel] logLevel The severity level of the message.
  /// [message] The message.
  ///
  void log(LogLevel logLevel, String message);
}

/// A Logger that print the message to the debug console.
class ConsoleLogger implements ILogger {
  // Properties
  LogLevel logLevel;

  // Methods

  ConsoleLogger(LogLevel level) {
    this.logLevel = level;
  }

  @override
  void log(LogLevel logLevel, String message) {
    if (logLevel.index < this.logLevel.index) {
      return;
    }

    print(message);
  }
}

class NullLogger implements ILogger {
  // Methods

  static NullLogger _instance;

  static NullLogger get instance {
    if (_instance == null) {
      _instance = NullLogger();
    }
    return _instance;
  }

  @override
  void log(LogLevel logLevel, String message) {}
}
