import 'dart:math';
import 'dart:typed_data';

import 'errors.dart';

class BinaryMessageFormat {

  static Uint8List write(Uint8List output) {
    var size = output.lengthInBytes;
    List<int> lenBuffer = [];
    do {
      var sizePart = size & 0x7f;
      size = size >> 7;
      if (size > 0) {
        sizePart |= 0x80;
      }
      lenBuffer.add(sizePart);
    }
    while (size > 0);

    size = output.lengthInBytes;

    var buffer = new Uint8List(lenBuffer.length + size);
    buffer.setAll(0, lenBuffer);
    buffer.setAll(lenBuffer.length, output);
    return buffer;
  }

  static List<Uint8List> parse(Uint8List input) {
    final List<Uint8List> result = [];
    const maxLengthPrefixSize = 5;
    const numBitsToShift = [0, 7, 14, 21, 28 ];

    for (int offset = 0; offset < input.lengthInBytes; offset++) {
      int numBytes = 0;
      int size = 0;
      int byteRead;
      do {
        byteRead = input[offset + numBytes];
        size = size | ((byteRead & 0x7f) << (numBitsToShift[numBytes]));
        numBytes++;
      } while (numBytes < min(maxLengthPrefixSize, input.lengthInBytes - offset) && (byteRead & 0x80) != 0);

      if ((byteRead & 0x80) != 0 && numBytes < maxLengthPrefixSize) {
        throw new GeneralError("Cannot read message size.");
      }

      if (numBytes == maxLengthPrefixSize && byteRead > 7) {
        throw new GeneralError("Messages bigger than 2GB are not supported.");
      }

      if (input.lengthInBytes >= (offset + numBytes + size)) {
        result.add(input.sublist(offset + numBytes, offset + numBytes + size));
      } else {
        throw new GeneralError("Incomplete message.");
      }

      offset = offset + numBytes + size;
    }

    return result;
  }
}
