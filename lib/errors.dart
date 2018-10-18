/// Error thrown when an HTTP request fails.
class HttpError implements Exception {
  // Properties

  /// The HTTP status code represented by this error.
  final num statusCode;

  final String message;

  // Methods

  /// Constructs a new instance.
  ///
  /// errorMessage A descriptive error message.
  ///  statusCode The HTTP status code represented by this error.
  ///
  HttpError(String errorMessage, num statusCode)
      : this.message = errorMessage,
        this.statusCode = statusCode;

  String toString() {
    return "$statusCode: $message";
  }
}

/// Error thrown when a timeout elapses.
class TimeoutError implements Exception {
  // Properties

  /// The error message
  final String message;

  // Methods

  /// Constructs a new instance.
  ///
  ///@param {string} errorMessage A descriptive error message.
  ///
  TimeoutError([String errorMessage = "A timeout occurred."])
      : this.message = errorMessage;

  String toString() {
    return message;
  }
}

/// Error thrown when an action is aborted.
class AbortError implements Exception {
  // Properties

  /// The error message
  final String message;

  // Methods

  /// Constructs a new instance of AbortError.
  ///
  /// errorMessage: A descriptive error message.
  ///
  AbortError([String message = "An abort occurred."]) : this.message = message;

  String toString() {
    return message;
  }
}

/// General Error that
class GeneralError implements Exception {
  // Properties

  /// The error message
  final String message;

  // Methods

  /// Constructs a new instance of GeneralError.
  ///
  /// errorMessage: A descriptive error message.
  ///
  GeneralError(String errorMessage) : this.message = errorMessage;

  String toString() {
    return message;
  }
}

class NotImplementedException extends GeneralError {
  // Methods

  NotImplementedException() : super("Not implemented.");

  String toString() {
    return message;
  }
}

class InvalidPayloadException extends GeneralError {
  // Methods

  InvalidPayloadException(String errorMessage) : super(errorMessage);

  String toString() {
    return message;
  }
}
