import 'dart:typed_data';

import 'package:signalr_netcore/binary_message_format.dart';
import 'package:test/test.dart';
import 'package:collection/collection.dart';

Function deepEq = const DeepCollectionEquality().equals;

void main() {
  // Common

  group('Binary Message Formatter write -> ', () {
    test('Empty bytes -> ', () {
      final payload = Uint8List.fromList([]);
      final expected = Uint8List.fromList([0x00]);
      final actual = BinaryMessageFormat.write(payload);
      expect(true, deepEq(actual, expected));
    });

    test('Some byte -> ', () {
      final payload = Uint8List.fromList([0x20]);
      final expected = Uint8List.fromList([0x01, 0x20]);
      final actual = BinaryMessageFormat.write(payload);
      expect(true, deepEq(actual, expected));
    });
  });
  group('Binary Message Formatter parse -> ', () {
    test('Empty bytes -> ', () {
      final payload = Uint8List.fromList([]);
      final expected = Uint8List.fromList([]);
      final actual = BinaryMessageFormat.parse(payload);
      expect(true, deepEq(actual, expected));
    });

    test('Zero byte -> ', () {
      final payload = Uint8List.fromList([0]);
      final expected = [Uint8List.fromList([])];
      final actual = BinaryMessageFormat.parse(payload);
      expect(true, deepEq(actual, expected));
    });

    test('01 ff bytes -> ', () {
      final payload = Uint8List.fromList([0x01, 0xff]);
      final expected = [
        Uint8List.fromList([0xff])
      ];
      final actual = BinaryMessageFormat.parse(payload);
      expect(true, deepEq(actual, expected));
    });

    test('0x01, 0xff, 0x01, 0x7f -> ', () {
      final payload = Uint8List.fromList([0x01, 0xff, 0x01, 0x7f]);
      final expected = [
        Uint8List.fromList([0xff]),
        Uint8List.fromList([0x7f])
      ];
      final actual = BinaryMessageFormat.parse(payload);
      expect(true, deepEq(actual, expected));
    });
  });

  group('Binary Message Formatter parse throws -> ', () {
    test('Cannot read size -> ', () {
      final payload = Uint8List.fromList([0x80]);

      try {
        BinaryMessageFormat.parse(payload);
      } on Exception catch (e) {
        expect(e.toString(), 'Exception: Cannot read message size.');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });

    test('Cannot read size -> ', () {
      final payload = Uint8List.fromList([0x02, 0x01, 0x80, 0x80]);

      try {
        BinaryMessageFormat.parse(payload);
      } on Exception catch (e) {
        expect(e.toString(), 'Exception: Cannot read message size.');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });

    test('Cannot read size -> ', () {
      final payload = Uint8List.fromList([
        0x07,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0x80
      ]); // the size of the second message is cut

      try {
        BinaryMessageFormat.parse(payload);
      } on Exception catch (e) {
        expect(e.toString(), 'Exception: Cannot read message size.');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });

    test('Cannot read size -> ', () {
      final payload = Uint8List.fromList([
        0x07,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0x01
      ]); // second message has only size

      try {
        BinaryMessageFormat.parse(payload);
      } on Exception catch (e) {
        expect(e.toString(), 'Exception: Incomplete message.');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });

    test('Cannot read size -> ', () {
      final payload = Uint8List.fromList([
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
      ]); // second message has only size

      try {
        BinaryMessageFormat.parse(payload);
      } on Exception catch (e) {
        expect(e.toString(),
            'Exception: Messages bigger than 2GB are not supported.');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });

    test('Cannot read size -> ', () {
      final payload = Uint8List.fromList([
        0x80,
        0x80,
        0x80,
        0x80,
        0x80,
      ]); // second message has only size

      try {
        BinaryMessageFormat.parse(payload);
      } on Exception catch (e) {
        expect(e.toString(),
            'Exception: Messages bigger than 2GB are not supported.');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });
    test('Cannot read size -> ', () {
      final payload = Uint8List.fromList([
        0x02,
        0x00,
      ]); // second message has only size

      try {
        BinaryMessageFormat.parse(payload);
      } on Exception catch (e) {
        expect(e.toString(), 'Exception: Incomplete message.');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });
    test('Cannot read size -> ', () {
      final payload = Uint8List.fromList([
        0xff,
        0xff,
        0xff,
        0xff,
        0x07,
      ]); // second message has only size

      try {
        BinaryMessageFormat.parse(payload);
      } on Exception catch (e) {
        expect(e.toString(), 'Exception: Incomplete message.');
        return;
      }
      throw new Exception("Expected ArgumentError");
    });
  });
}
