import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:msgpack2/msgpack2.dart';

import 'errors.dart';
import 'ihub_protocol.dart';
import 'itransport.dart';
import 'binary_message_format.dart';

const String MSGPACK_HUB_PROTOCOL_NAME = "messagepack";
const int PROTOCOL_VERSION = 1;
const TransferFormat TRANSFER_FORMAT = TransferFormat.Binary;
// ignore: non_constant_identifier_names
Uint8List SERIALIZED_PING_MESSAGE = Uint8List.fromList([0x91, MessageType.Ping.index]);

class MsgpackHubProtocol implements IHubProtocol {
  // Properties

  @override
  String get name => MSGPACK_HUB_PROTOCOL_NAME;

  @override
  int get version => PROTOCOL_VERSION;

  @override
  TransferFormat get transferFormat => TRANSFER_FORMAT;

  // Methods
  /// Creates an array of {@link @aspnet/signalr.HubMessage} objects from the specified serialized representation.
  ///
  /// A Uint8List containing the serialized representation.
  /// A logger that will be used to log messages that occur during parsing.
  ///
  @override
  List<HubMessageBase> parseMessages(Object input, Logger logger) {
    // Only JsonContent is allowed.
    if (!(input is Uint8List)) {
      throw new GeneralError(
          "Invalid input for BIANRY hub protocol. Expected a Uint8List.");
    }

    final hubMessages = List<HubMessageBase>();

    if (input == null) {
      return hubMessages;
    }

    // Parse the messages
    final messages = BinaryMessageFormat.parse(input);

    for (var message in messages) {
      HubMessageBase parsedMessage = _parseMessage(message, logger);
      // Can be null for an unknown message. Unknown message is logged in parseMessage
      if (parsedMessage != null) {
        hubMessages.add(parsedMessage);
      }
    }

    return hubMessages;
  }

  HubMessageBase _parseMessage(Uint8List input, Logger logger) {
    if (input.length == 0) {
      throw new InvalidPayloadException("Invalid payload.");
    }

    List properties = deserialize(input);
    if (properties.length == 0) {
      throw new InvalidPayloadException("Invalid payload.");
    }

    final messageType = properties[0];

    switch (MessageType.values[messageType]) {
      case MessageType.Invocation:
        return _createInvocationMessage(_readHeaders(properties), properties);
      case MessageType.StreamItem:
        return _createStreamItemMessage(_readHeaders(properties), properties);
      case MessageType.Completion:
        return _createCompletionMessage(_readHeaders(properties), properties);
      case MessageType.Ping:
        return _createPingMessage(properties);
      case MessageType.Close:
        return _createCloseMessage(properties);
      default:
        // Future protocol changes can add message types, old clients can ignore them
        logger?.info("Unknown message type '$messageType' ignored.");
        return null;
    }
  }

  /// Writes the specified HubMessage to a string and returns it.
  ///
  /// message: The message to write.
  /// Returns a string containing the serialized representation of the message.
  ///
  @override
  Uint8List writeMessage(HubMessageBase message) {
    switch (message.type) {
      case MessageType.Invocation:
        return _writeInvocation(message as InvocationMessage);
      case MessageType.StreamInvocation:
        return _writeStreamInvocation(message as StreamInvocationMessage);
      case MessageType.StreamItem:
      case MessageType.Completion:
        throw new GeneralError("Writing messages of type " + message.type.toString() + " is not supported.");
      case MessageType.Ping:
        return BinaryMessageFormat.write(SERIALIZED_PING_MESSAGE);
      default:
        throw new GeneralError("Invalid message type.");
    }
  }

  HubMessageBase _createCloseMessage(List properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 2) {
      throw new InvalidPayloadException("Invalid payload for Close message.");
    }

    return new CloseMessage(properties[1]);
  }

  HubMessageBase _createPingMessage(List properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 1) {
      throw new InvalidPayloadException("Invalid payload for Ping message.");
    }

    return new PingMessage();
  }

  InvocationMessage _createInvocationMessage(
      MessageHeaders headers, List properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 5) {
      throw new InvalidPayloadException("Invalid payload for Invocation message.");
    }

    return new InvocationMessage(
        properties[3] as String, properties[4], headers, properties[2]);
  }

  StreamItemMessage _createStreamItemMessage(
      MessageHeaders headers, List properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 4) {
      throw new InvalidPayloadException("Invalid payload for StreamItem message.");
    }

    return new StreamItemMessage(properties[3], headers, properties[2]);
  }

  CompletionMessage _createCompletionMessage(
      MessageHeaders headers, List properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 4) {
      throw new InvalidPayloadException("Invalid payload for Completion message.");
    }

    const errorResult = 1;
    const voidResult = 2;
    const nonVoidResult = 3;

    int resultKind = properties[3];

    if (resultKind != voidResult && properties.length < 5) {
      throw new GeneralError("Invalid payload for Completion message.");
    }

    String error;
    Object result;

    switch (resultKind) {
      case errorResult:
        error = properties[4];
        break;
      case nonVoidResult:
        result = properties[4];
        break;
    }

    return new CompletionMessage(error, result, headers, properties[2]);
  }

  Map convertMessageHeadersToMap (MessageHeaders messageHeaders) {
    Map<String, String> returnObj = new Map();
    for (var headerName in messageHeaders.names) {
      returnObj[headerName] = messageHeaders.getHeaderValue(headerName);
    }

    return returnObj;
  }

  Uint8List _writeInvocation(InvocationMessage invocationMessage) {
    var payload = serialize([
      MessageType.Invocation.index,
      convertMessageHeadersToMap(invocationMessage.headers),
      invocationMessage.invocationId,
      invocationMessage.target,
      invocationMessage.arguments
    ]);

    return BinaryMessageFormat.write(payload);
  }

  Uint8List _writeStreamInvocation(
      StreamInvocationMessage streamInvocationMessage) {
    var payload = serialize([
      MessageType.StreamInvocation.index,
      convertMessageHeadersToMap(streamInvocationMessage.headers),
      streamInvocationMessage.invocationId,
      streamInvocationMessage.target,
      streamInvocationMessage.arguments
    ]);

    return BinaryMessageFormat.write(payload);
  }

  MessageHeaders _readHeaders(List properties) {
    MessageHeaders headers = properties[1] as MessageHeaders;
    return headers;
  }
}
