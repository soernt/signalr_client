import 'dart:collection';

import 'package:logging/logging.dart';

import 'errors.dart';
import 'itransport.dart';

/// Defines the type of a Hub Message.
enum MessageType {
  /// MessageType is not defined.
  Undefined, // = 0,
  /// Indicates the message is an Invocation message and implements the {@link @microsoft/signalr.InvocationMessage} interface.
  Invocation, // = 1,
  /// Indicates the message is a StreamItem message and implements the {@link @microsoft/signalr.StreamItemMessage} interface.
  StreamItem, // = 2,
  /// Indicates the message is a Completion message and implements the {@link @microsoft/signalr.CompletionMessage} interface.
  Completion, // = 3,
  /// Indicates the message is a Stream Invocation message and implements the {@link @microsoft/signalr.StreamInvocationMessage} interface.
  StreamInvocation, // = 4,
  /// Indicates the message is a Cancel Invocation message and implements the {@link @microsoft/signalr.CancelInvocationMessage} interface.
  CancelInvocation, // = 5,
  /// Indicates the message is a Ping message and implements the {@link @microsoft/signalr.PingMessage} interface.
  Ping, // = 6,
  /// Indicates the message is a Close message and implements the {@link @microsoft/signalr.CloseMessage} interface.
  Close, // = 7,
}

MessageType? parseMessageTypeFromString(int? value) {
  if (value == null) {
    return null;
  }

  switch (value) {
    case 1:
      return MessageType.Invocation;
    case 2:
      return MessageType.StreamItem;
    case 3:
      return MessageType.Completion;
    case 4:
      return MessageType.StreamInvocation;
    case 5:
      return MessageType.CancelInvocation;
    case 6:
      return MessageType.Ping;
    case 7:
      return MessageType.Close;
    default:
      throw GeneralError("A MessageType of {value} is not supported.");
  }
}

/// Defines a dictionary of string keys and string values representing headers attached to a Hub message.
class MessageHeaders {
  static const String AuthorizationHeaderName = "Authorization";

  // Properties
  HashMap<String, String?>? _headers;

  Iterable<String> get names => _headers!.keys;
  HashMap<String, String?>? get asMap => _headers;

  bool get isEmtpy => _headers!.length == 0;

  // Methods
  MessageHeaders() {
    _headers = HashMap<String, String?>();
  }

  /// Gets the header with the specified key.
  String? getHeaderValue(String name) {
    return _headers![name];
  }

  /// Sets the header with the specified key.
  void setHeaderValue(String name, String? value) {
    _headers![name] = value;
  }

  /// removes the given header
  void removeHeader(String name) {
    if (_headers!.containsKey(name)) {
      _headers!.remove(name);
    }
  }

  @override
  String toString() {
    if (isEmtpy) return '(no headers)';

    String str = '';
    for (var name in names) {
      if (str.isNotEmpty) str += ', ';
      str += '{ $name: ${_headers![name]} }';
    }

    return str;
  }
}

/// Defines properties common to all Hub messages.
abstract class HubMessageBase {
  // Properties

  /// A [MessageType] value indicating the type of this message.
  final MessageType type;

  // Methods
  HubMessageBase(MessageType type) : this.type = type;
}

/// Defines properties common to all Hub messages relating to a specific invocation.
abstract class HubInvocationMessage extends HubMessageBase {
  // Properties
  /// A {@link @microsoft/signalr.MessageHeaders} dictionary containing headers attached to the message.
  final MessageHeaders headers;

  ///The ID of the invocation relating to this message.
  ///
  ///This is expected to be present for StreamInvocationMessage and CompletionMessage. It may
  ///be 'undefined' for an InvocationMessage if the sender does not expect a response.
  final String? invocationId;

  // Methods
  HubInvocationMessage(
      MessageType messageType, MessageHeaders? headers, String? invocationId)
      : this.headers = headers ?? MessageHeaders(),
        this.invocationId = invocationId,
        super(messageType);
}

/// A hub message representing a non-streaming invocation.
class InvocationMessage extends HubInvocationMessage {
  // Properites

  /// The target method name.
  final String? target;

  /// The target method arguments.
  final List<Object>? arguments;

  /// The target method's stream IDs.
  final List<String>? streamIds;

  // Methods
  InvocationMessage(String? target, List<Object>? arguments,
      List<String>? streamIds, MessageHeaders? headers, String? invocationId)
      : this.target = target,
        this.arguments = arguments,
        this.streamIds = streamIds,
        super(MessageType.Invocation, headers, invocationId);
}

/// A hub message representing a streaming invocation.
class StreamInvocationMessage extends HubInvocationMessage {
  // Properites

  /// The target method name.
  final String target;

  /// The target method arguments.
  final List<Object> arguments;

  /// The target method's stream IDs.
  final List<String> streamIds;

  // Methods
  StreamInvocationMessage(String target, List<Object> arguments,
      List<String> streamIds, MessageHeaders headers, String invocationId)
      : this.target = target,
        this.arguments = arguments,
        this.streamIds = streamIds,
        super(MessageType.StreamInvocation, headers, invocationId);
}

/// A hub message representing a single item produced as part of a result stream.
class StreamItemMessage extends HubInvocationMessage {
  // Properites

  /// The item produced by the server.
  final Object? item;

  // Methods
  StreamItemMessage(Object? item, MessageHeaders? headers, String? invocationId)
      : this.item = item,
        super(MessageType.StreamItem, headers, invocationId);
}

/// A hub message representing the result of an invocation.
class CompletionMessage extends HubInvocationMessage {
  // Properties

  /// The error produced by the invocation, if any.
  ///
  /// Either CompletionMessage.error CompletionMessage.result must be defined, but not both.
  final String? error;

  /// The result produced by the invocation, if any.
  ///
  /// Either {@link @microsoft/signalr.CompletionMessage.error} or {@link @microsoft/signalr.CompletionMessage.result} must be defined, but not both.
  final Object? result;

  // Methods
  CompletionMessage(
      String? error, Object? result, MessageHeaders? headers, String? invocationId)
      : this.error = error,
        this.result = result,
        super(MessageType.Completion, headers, invocationId);
}

/// A hub message indicating that the sender is still active.
class PingMessage extends HubMessageBase {
  // Methods

  PingMessage() : super(MessageType.Ping);
}

/// A hub message indicating that the sender is closing the connection.
///
/// If {@link @microsoft/signalr.CloseMessage.error} is defined, the sender is closing the connection due to an error.
///
class CloseMessage extends HubMessageBase {
  // Properites

  /// The error that triggered the close, if any.
  ///
  /// If this property is undefined, the connection was closed normally and without error.
  final String? error;

  /// If true, clients with automatic reconnects enabled should attempt to reconnect after receiving the CloseMessage. Otherwise, they should not. */
  final bool? allowReconnect;

  //Methods
  CloseMessage({String? error, bool? allowReconnect})
      : this.error = error,
        this.allowReconnect = allowReconnect,
        super(MessageType.Close);
}

/// A hub message sent to request that a streaming invocation be canceled.
class CancelInvocationMessage extends HubInvocationMessage {
  // Methods
  CancelInvocationMessage(MessageHeaders headers, String? invocationId)
      : super(MessageType.CancelInvocation, headers, invocationId);
}

/// A protocol abstraction for communicating with SignalR Hubs.
abstract class IHubProtocol {
  // Properties

  /// The name of the protocol. This is used by SignalR to resolve the protocol between the client and server.
  final String name;

  /// The version of the protocol.
  final int version;

  /// The TransferFormat of the protocol. */
  final TransferFormat transferFormat;

  // Methods
  IHubProtocol(String name, int number, TransferFormat transferFormat)
      : this.name = name,
        this.version = number,
        this.transferFormat = transferFormat;

  /// Creates an array of {@link @microsoft/signalr.HubMessage} objects from the specified serialized representation.
  ///
  /// If transferFormat is 'Text', the `input` parameter must be a string, otherwise it must be an ArrayBuffer.
  ///
  /// [input] A string (json), or Uint8List (binary) containing the serialized representation.
  /// [Logger] logger A logger that will be used to log messages that occur during parsing.

  List<HubMessageBase> parseMessages(Object input, Logger? logger);

  /// Writes the specified HubMessage to a string or ArrayBuffer and returns it.
  ///
  /// If transferFormat is 'Text', the result of this method will be a string, otherwise it will be an ArrayBuffer.
  ///
  /// [message] The message to write.
  /// returns  A string or ArrayBuffer containing the serialized representation of the message.

  Object writeMessage(HubMessageBase message);
}
