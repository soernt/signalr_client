import 'package:logging/logging.dart';

import 'ihub_protocol.dart';
import 'signalr_client.dart';

bool isStringEmpty(String value) {
  return (value == null) || (value.length == 0);
}

bool isListEmpty(List value) {
  return (value == null) || (value.length == 0);
}

Future<void> sendMessage(
    Logger logger,
    String transportName,
    SignalRHttpClient httpClient,
    String url,
    AccessTokenFactory accessTokenFactory,
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
