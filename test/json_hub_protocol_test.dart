import 'package:signalr_netcore/text_message_format.dart';
import 'package:signalr_netcore/ihub_protocol.dart';
import 'package:signalr_netcore/json_hub_protocol.dart';
import 'package:test/test.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

Function deepEq = const DeepCollectionEquality().equals;

void main() {
  // Common

  group('Json hub protocol -> ', () {
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
        headers: headers, //with headers
        arguments: [
          42,
          true,
          "test",
          ["x1", "y2"],
        ],
        invocationId: "123",
      )
    ].forEach((e) {
      test('can write/read non-blocking Invocation message -> ', () {
        final invocation = e;
        final protocol = new JsonHubProtocol();
        final writtenMsg = protocol.writeMessage(invocation);
        final parsedMessages =
            protocol.parseMessages(writtenMsg, Logger("JsonHubProtocol"));

        final equalityCheck =
            deepEq(parsedMessages.toString(), ([invocation]).toString());
        expect(equalityCheck, true);
      });
    });

    ([
      [
        TextMessageFormat.write(
            '{"type":3, "invocationId": "abc", "error": "Err", "result": null, "headers": {}}'),
        CompletionMessage(
          error: "Err",
          headers: MessageHeaders(),
          invocationId: "abc",
          result: null,
        )
      ],
      [
        TextMessageFormat.write(
            '{"type":3, "invocationId": "abc", "result": "OK", "headers": {}}'),
        CompletionMessage(
          headers: MessageHeaders(),
          invocationId: "abc",
          result: "OK",
        )
      ],
      [
        TextMessageFormat.write(
            '{"type":3, "invocationId": "abc", "result": null, "headers": {}}'),
        CompletionMessage(
          headers: MessageHeaders(),
          invocationId: "abc",
          result: null,
        )
      ],
      [
        TextMessageFormat.write(
            '{"type":3, "invocationId": "abc", "result": null, "headers": {}, "extraParameter":"value"}'),
        CompletionMessage(
          headers: MessageHeaders(),
          invocationId: "abc",
          result: null,
        )
      ],
    ]).forEach((e) {
      test('Completion message -> ', () {
        final protocol = new JsonHubProtocol();
        final payload = e[0];
        final expectedMessage = e[1];
        final parsedMessages =
            protocol.parseMessages(payload, Logger("JsonHubProtocol"));
        final equalityCheck =
            deepEq(parsedMessages.toString(), ([expectedMessage]).toString());
        expect(equalityCheck, true);
      });
    });

    [
      [
        TextMessageFormat.write(
            '{"type":2, "invocationId": "abc", "headers": {}, "item": 8}'),
        StreamItemMessage(
          headers: MessageHeaders(),
          invocationId: "abc",
          item: 8,
        )
      ],
      [
        TextMessageFormat.write(
            '{"type":2, "invocationId": "abc", "headers": {}, "item": 1648116122951}'),
        StreamItemMessage(
            headers: MessageHeaders(),
            invocationId: "abc",
            item: DateTime.parse('2022-03-24T15:32:02.951')
                .millisecondsSinceEpoch)
      ],
      [
        TextMessageFormat.write(
            '{"type":2, "invocationId": "abc", "headers": {"foo": "bar"}, "item": 8}'),
        StreamItemMessage(
          invocationId: "abc",
          item: 8,
          headers: headers,
        )
      ],
      [TextMessageFormat.write('{"type":6}'), PingMessage()]
    ].forEach((e) {
      test('StreamItem message -> ', () {
        final protocol = new JsonHubProtocol();
        final payload = e[0];
        final expectedMessage = e[1];
        final parsedMessages =
            protocol.parseMessages(payload, Logger("JsonHubProtocol"));
        final equalityCheck =
            deepEq(parsedMessages.toString(), ([expectedMessage]).toString());
        expect(equalityCheck, true);
      });
    });
  });
}
