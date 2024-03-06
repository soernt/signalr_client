import 'dart:async';

import 'errors.dart';

/// Specifies a specific HTTP transport type.
enum HttpTransportType {
  /// Specified no transport preference. */
  None, // = 0,
  /// Specifies the WebSockets transport. */
  WebSockets, // = 1,
  /// Specifies the Server-Sent Events transport. */
  ServerSentEvents, // = 2,
  /// Specifies the Long Polling transport. */
  LongPolling, // = 4,
}

HttpTransportType httpTransportTypeFromString(String? value) {
  if (value == null || value == "") {
    return HttpTransportType.None;
  }

  value = value.toUpperCase();
  switch (value) {
    case "WEBSOCKETS":
      return HttpTransportType.WebSockets;
    case "SERVERSENTEVENTS":
      return HttpTransportType.ServerSentEvents;
    case "LONGPOLLING":
      return HttpTransportType.LongPolling;
    default:
      throw new GeneralError("$value is not a supported HttpTransportType");
  }
}

/// Specifies the transfer format for a connection.
enum TransferFormat {
  /// TransferFormat is not defined.
  Undefined, // = 0,
  /// Specifies that only text data will be transmitted over the connection.
  Text, // = 1,
  /// Specifies that binary data will be transmitted over the connection.
  Binary, // = 2,
}

TransferFormat getTransferFormatFromString(String? value) {
  if (value == null || value == "") {
    return TransferFormat.Undefined;
  }

  value = value.toUpperCase();
  switch (value) {
    case "TEXT":
      return TransferFormat.Text;
    case "BINARY":
      return TransferFormat.Binary;
    default:
      throw new GeneralError("$value is not a supported HttpTransportType");
  }
}

/// Data received call back.
/// data: the content. Either a string (json) or Uint8List (binary)
typedef OnReceive = void Function(Object? data);

///
typedef OnClose = void Function({Exception? error});

typedef AccessTokenFactory = Future<String> Function();

/// An abstraction over the behavior of transports. This is designed to support the framework and not intended for use by applications.
abstract class ITransport {
  Future<void> connect(String? url, TransferFormat transferFormat);

  /// data: the content. Either a string (json) or Uint8List (binary)
  Future<void> send(Object data);
  Future<void> stop();
  OnReceive? onReceive;
  OnClose? onClose;
}
