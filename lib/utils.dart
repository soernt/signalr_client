import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'ihub_protocol.dart';
import 'signalr_client.dart';

bool isIntEmpty(int? value) {
  return (value == null);
}

bool isStringEmpty(String? value) {
  return (value == null) || (value.length == 0);
}

bool isListEmpty(List? value) {
  return (value == null) || (value.length == 0);
}

String getDataDetail(Object? data, bool includeContent) {
  var detail = "";
  if (data is Uint8List) {
    detail = "Binary data of length ${data.lengthInBytes}";
    if (includeContent) {
      detail += ". Content: '${formatArrayBuffer(data)}'";
    }
  } else if (data is String) {
    detail = "String data of length ${data.length}";
    if (includeContent) {
      detail += ". Content: '$data'";
    }
  }
  return detail;
}

String formatArrayBuffer(Uint8List data) {
  // Uint8Array.map only supports returning another Uint8Array?
  var str = "";
  data.forEach((val) {
    var pad = val < 16 ? "0" : "";
    str += "0x$pad${val.toString()} ";
  });

  // Trim of trailing space.
  return str.substring(0, str.length - 1);
}

Future<void> sendMessage(
    Logger? logger,
    String transportName,
    SignalRHttpClient httpClient,
    String? url,
    AccessTokenFactory? accessTokenFactory,
    Object content,
    bool logMessageContent) async {
  MessageHeaders headers = MessageHeaders();
  if (accessTokenFactory != null) {
    final token = await accessTokenFactory();
    if (!isStringEmpty(token)) {
      headers.setHeaderValue("Authorization", "Bearer $token");
    }
  }

  // logger.log(LogLevel.Trace, `(${transportName} transport) sending data. ${getDataDetail(content, logMessageContent)}.`);
  logger?.finest("($transportName transport) sending data.");

  //final responseType = content is String ? "arraybuffer" : "text";
  SignalRHttpRequest req =
      SignalRHttpRequest(content: content, headers: headers);
  final response = await httpClient.post(url, options: req);

  logger?.finest(
      "($transportName transport) request complete. Response status: ${response.statusCode}.");
}
