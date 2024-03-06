import 'dart:convert';

import 'package:logging/logging.dart';

import 'errors.dart';
import 'ihub_protocol.dart';
import 'itransport.dart';
import 'text_message_format.dart';
import 'utils.dart';

const String JSON_HUB_PROTOCOL_NAME = "json";
const int PROTOCOL_VERSION = 1;
const TransferFormat TRANSFER_FORMAT = TransferFormat.Text;

class JsonHubProtocol implements IHubProtocol {
  // Properties

  @override
  String get name => JSON_HUB_PROTOCOL_NAME;

  @override
  int get version => PROTOCOL_VERSION;

  @override
  TransferFormat get transferFormat => TRANSFER_FORMAT;

  // Methods

  /// Creates an array of {@link @microsoft/signalr.HubMessage} objects from the specified serialized representation.
  ///
  /// A string containing the serialized representation.
  /// A logger that will be used to log messages that occur during parsing.
  ///
  @override
  List<HubMessageBase> parseMessages(Object input, Logger? logger) {
    // Only JsonContent is allowed.
    if (!(input is String)) {
      throw new GeneralError(
          "Invalid input for JSON hub protocol. Expected a string.");
    }

    final jsonInput = input;
    final List<HubMessageBase> hubMessages = [];

    // Parse the messages
    final messages = TextMessageFormat.parse(jsonInput);
    for (var message in messages) {
      final jsonData = json.decode(message);
      final messageType = _getMessageTypeFromJson(jsonData);
      HubMessageBase messageObj;

      switch (messageType) {
        case MessageType.Invocation:
          messageObj = _getInvocationMessageFromJson(jsonData);
          break;
        case MessageType.StreamItem:
          messageObj = _getStreamItemMessageFromJson(jsonData);
          break;
        case MessageType.Completion:
          messageObj = _getCompletionMessageFromJson(jsonData);
          break;
        case MessageType.Ping:
          messageObj = _getPingMessageFromJson(jsonData);
          break;
        case MessageType.Close:
          messageObj = _getCloseMessageFromJson(jsonData);
          break;
        default:
          // Future protocol changes can add message types, old clients can ignore them
          logger?.info("Unknown message type '$messageType' ignored.");
          continue;
      }
      hubMessages.add(messageObj);
    }

    return hubMessages;
  }

  static MessageType? _getMessageTypeFromJson(Map<String, dynamic> json) {
    return parseMessageTypeFromString(json["type"]);
  }

  static MessageHeaders? createMessageHeadersFromJson(dynamic jsonData) {
    if (jsonData == null) {
      return null;
    } else {
      final _headers1 = new Map<String, String>.from(jsonData);
      final headers = MessageHeaders();
      _headers1.forEach((key, value) {
        headers.setHeaderValue(key, value);
      });
      return headers;
    }
  }

  static InvocationMessage _getInvocationMessageFromJson(
      Map<String, dynamic> jsonData) {
    final MessageHeaders? headers =
        createMessageHeadersFromJson(jsonData["headers"]);
    final message = InvocationMessage(
        target: jsonData["target"],
        arguments: jsonData["arguments"]?.cast<Object?>().toList(),
        streamIds: (jsonData["streamIds"] == null)
            ? null
            : (List<String>.from(jsonData["streamIds"] as List<dynamic>)),
        headers: headers,
        invocationId: jsonData["invocationId"] as String?);

    _assertNotEmptyString(
        message.target, "Invalid payload for Invocation message.");
    if (message.invocationId != null) {
      _assertNotEmptyString(
          message.invocationId, "Invalid payload for Invocation message.");
    }

    return message;
  }

  static StreamItemMessage _getStreamItemMessageFromJson(
      Map<String, dynamic> jsonData) {
    final MessageHeaders? headers =
        createMessageHeadersFromJson(jsonData["headers"]);
    final message = StreamItemMessage(
        item: jsonData["item"],
        headers: headers,
        invocationId: jsonData["invocationId"] as String?);

    _assertNotEmptyString(
        message.invocationId, "Invalid payload for StreamItem message.");
    if (message.item == null) {
      throw InvalidPayloadException("Invalid payload for StreamItem message.");
    }
    return message;
  }

  static CompletionMessage _getCompletionMessageFromJson(
      Map<String, dynamic> jsonData) {
    final MessageHeaders? headers =
        createMessageHeadersFromJson(jsonData["headers"]);
    final message = CompletionMessage(
        error: jsonData["error"],
        result: jsonData["result"],
        headers: headers,
        invocationId: jsonData["invocationId"] as String?);

    if ((message.result != null) && (message.error != null)) {
      throw InvalidPayloadException("Invalid payload for Completion message.");
    }

    if ((message.result == null) && (message.error != null)) {
      _assertNotEmptyString(
          message.error, "Invalid payload for Completion message.");
    }

    return message;
  }

  static PingMessage _getPingMessageFromJson(Map<String, dynamic> jsonData) {
    return PingMessage();
  }

  static CloseMessage _getCloseMessageFromJson(Map<String, dynamic> jsonData) {
    return CloseMessage(
        error: jsonData["error"], allowReconnect: jsonData["allowReconnect"]);
  }

  /// Writes the specified HubMessage to a string and returns it.
  ///
  /// message: The message to write.
  /// Returns a string containing the serialized representation of the message.
  ///
  @override
  String writeMessage(HubMessageBase message) {
    var jsonObj = _messageAsMap(message);
    return TextMessageFormat.write(json.encode(jsonObj));
  }

  static dynamic _messageAsMap(dynamic message) {
    if (message == null) {
      throw GeneralError("Cannot encode message which is null.");
    }

    if (!(message is HubMessageBase)) {
      throw GeneralError("Cannot encode message of type '${message.typ}'.");
    }

    final messageType = message.type.index;

    if (message is InvocationMessage) {
      return {
        "type": messageType,
        "headers": message.headers.asMap,
        "invocationId": message.invocationId,
        "target": message.target,
        "arguments": message.arguments,
        "streamIds": message.streamIds,
      }..removeWhere((key, value) => value == null);
    }

    if (message is StreamInvocationMessage) {
      return {
        "type": messageType,
        "headers": message.headers.asMap,
        "invocationId": message.invocationId,
        "target": message.target,
        "arguments": message.arguments,
        "streamIds": message.streamIds,
      };
    }

    if (message is StreamItemMessage) {
      return {
        "type": messageType,
        "headers": message.headers.asMap,
        "invocationId": message.invocationId,
        "item": message.item
      };
    }

    if (message is CompletionMessage) {
      return {
        "type": messageType,
        "invocationId": message.invocationId,
        "headers": message.headers.asMap,
        "error": message.error,
        "result": message.result
      };
    }

    if (message is PingMessage) {
      return {"type": messageType};
    }

    if (message is CloseMessage) {
      return {
        "type": messageType,
        "error": message.error,
        "allowReconnect": message.allowReconnect
      };
    }

    if (message is CancelInvocationMessage) {
      return {"type": messageType, "invocationId": message.invocationId};
    }

    throw GeneralError("Converting '${message.type}' is not implemented.");
  }

  static void _assertNotEmptyString(String? value, String errorMessage) {
    if (isStringEmpty(value)) {
      throw InvalidPayloadException(errorMessage);
    }
  }
}
