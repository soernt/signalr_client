import 'dart:typed_data';
import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/ihub_protocol.dart';
import 'package:signalr_netcore/msgpack_hub_protocol.dart';
import 'package:test/test.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

Function deepEq = const DeepCollectionEquality().equals;

void main() {
  // Common

  group('Msgpack hub protocol -> ', () {
    final headers = MessageHeaders();
    headers.setHeaderValue("foo", "bar");
    [
      InvocationMessage(
        target: "myMethod",
        arguments: [
          42,
          true,
          "test",
          ["x1", "y2"],
        ],
        streamIds: [],
      ),
      InvocationMessage(
        target: "myMethod",
        arguments: [
          42,
          true,
          52.64, // with float
          "test",
          ["x1", "y2"],
        ],
        invocationId: "123", // with invocation id
        streamIds: [],
      ),
      InvocationMessage(
        target: "myMethod",
        //headers: headers, //with headers
        arguments: [
          42,
          true,
          "test",
          ["x1", "y2"],
        ],
        invocationId: "123",
        streamIds: [],
      )
    ].forEach((e) {
      test('can write/read non-blocking Invocation message -> ', () {
        final invocation = e;
        final protocol = new MessagePackHubProtocol();
        final writtenMsg = protocol.writeMessage(invocation);
        final parsedMessages = protocol.parseMessages(
            writtenMsg, Logger("MessagepackHubProtocol"));

        final equalityCheck =
            deepEq(parsedMessages.toString(), ([invocation]).toString());
        expect(equalityCheck, true);
      });
    });

    [
      CompletionMessage(
        error: "Err",
        headers: MessageHeaders(),
        invocationId: "abc",
      ),
      CompletionMessage(
        headers: MessageHeaders(),
        invocationId: "abc",
        result: "OK",
      )
    ].forEach((e) {
      test('Completion message -> ', () {
        final protocol = new MessagePackHubProtocol();
        final msg = e;
        final writtenMessage = protocol.writeMessage(msg);
        final parsedMessages = protocol.parseMessages(
            writtenMessage, Logger("MessagepackHubProtocol"));
        final equalityCheck =
            deepEq(parsedMessages.toString(), ([msg]).toString());
        expect(equalityCheck, true);
      });
    });
    test('Ping message -> ', () {
      final protocol = new MessagePackHubProtocol();
      final buf = [
        0x02, // length prefix
        0x91, // message array length = 1 (fixarray)
        0x06,
      ];

      final parsedMessages = protocol.parseMessages(
          Uint8List.fromList(buf), Logger("MessagepackHubProtocol"));
      final msgs = parsedMessages.map((e) {
        return protocol.writeMessage(e);
      }).toList();
      expect(deepEq(msgs, [buf]), true);
    });

    test('Cancel message -> ', () {
      final protocol = new MessagePackHubProtocol();
      final buf = [
        0x07, // length prefix
        0x93, // message array length = 1 (fixarray)
        0x05, // type = 5 = CancelInvocation (fixnum)
        0x80, // headers
        0xa3, // invocationID = string length 3
        0x61, // a
        0x62, // b
        0x63,
      ];

      final writtenMessage =
          protocol.writeMessage(CancelInvocationMessage(invocationId: "abc"));

      expect(deepEq(Uint8List.fromList(buf), writtenMessage), true);
    });
  });

  [
    /*
    [
      "message with no payload",
      [0x00],
      "Invalid payload."
    ],
    [
      "message with empty array",
      [0x01, 0x90],
      "Cannot encode message which is null."
    ],
    
    [
      "message without outer array",
      [0x01, 0xc2],
      "Cannot encode message which is null."
    ],
    [
      "message with invalid headers",
      [0x03, 0x92, 0x01, 0x05],
      "Invalid headers."
    ],
    */
    [
      "Invocation message with invalid invocation id",
      [0x03, 0x92, 0x01, 0x80],
      "Invalid payload for Invocation message."
    ],
    [
      "StreamItem message with invalid invocation id",
      [0x03, 0x92, 0x02, 0x80],
      "Invalid payload for StreamItem message."
    ],
    [
      "Completion message with invalid invocation id",
      [0x04, 0x93, 0x03, 0x80, 0xa0],
      "Invalid payload for Completion message."
    ],
    [
      "Completion message with missing result",
      [0x05, 0x94, 0x03, 0x80, 0xa0, 0x01],
      "Invalid payload for Completion message."
    ],
    [
      "Completion message with missing error",
      [0x05, 0x94, 0x03, 0x80, 0xa0, 0x03],
      "Invalid payload for Completion message."
    ],
  ].forEach((e) {
    final name = e[0];
    final payload = e[1] as List<int>;
    test('$name -> ', () {
      final protocol = new MessagePackHubProtocol();

      expect(
          () => protocol.parseMessages(
              Uint8List.fromList(payload), Logger("MessagepackHubProtocol")),
          throwsA(predicate((e) => e is GeneralError)));
    });
  });

  test('can read multiple messages -> ', () {
    final protocol = new MessagePackHubProtocol();
    final payload = [
      0x08,
      0x94,
      0x02,
      0x80,
      0xa3,
      0x61,
      0x62,
      0x63,
      0x08,
      0x0b,
      0x95,
      0x03,
      0x80,
      0xa3,
      0x61,
      0x62,
      0x63,
      0x03,
      0xa2,
      0x4f,
      0x4b
    ];
    final expectedMessages = [
      StreamItemMessage(
          headers: MessageHeaders(), invocationId: "abc", item: 8),
      CompletionMessage(
          headers: MessageHeaders(), invocationId: "abc", result: "OK")
    ].map((e) {
      return e.toString();
    }).toList();
    final parsedMessages = (protocol.parseMessages(
            Uint8List.fromList(payload), Logger("MessagepackHubProtocol")))
        .map((e) {
      return e.toString();
    }).toList();
    expect(deepEq(expectedMessages, parsedMessages), true);
  });
}
