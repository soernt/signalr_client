class TextMessageFormat {
  // Properties

  static const RecordSeparatorCode = 0x1e;
  static String recordSeparator =
      String.fromCharCode(TextMessageFormat.RecordSeparatorCode);

  static String write(String output) {
    return "$output${TextMessageFormat.recordSeparator}";
  }

  static List<String> parse(String input) {
    if (input[input.length - 1] != TextMessageFormat.recordSeparator) {
      throw new Exception("Message is incomplete.");
    }

    var messages = input.split(TextMessageFormat.recordSeparator);

    messages.removeLast();
    return messages;
  }
}
