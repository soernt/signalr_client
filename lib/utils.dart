import 'ihub_protocol.dart';
import 'ilogger.dart';
import 'signalr_client.dart';

ILogger createLogger(Object logger) {
  if (logger == null) {
    return NullLogger.instance;
  }

  if ((logger is ILogger)) {
    return logger;
  }

  return new ConsoleLogger(logger as LogLevel);
}

bool isStringEmpty(String value) {
  return (value == null) || (value.length == 0);
}

bool isListEmpty(List value) {
  return (value == null) || (value.length == 0);
}

Future<void> sendMessage(ILogger logger, String transportName, SignalRHttpClient httpClient, String url, AccessTokenFactory accessTokenFactory, Object content, bool logMessageContent) async {
  MessageHeaders headers = MessageHeaders();
  if (accessTokenFactory != null) {
    final token = await accessTokenFactory();
    if (!isStringEmpty(token)) {
      headers.setHeaderValue("Authorization", "Bearer $token");
    }
  }

  // logger.log(LogLevel.Trace, `(${transportName} transport) sending data. ${getDataDetail(content, logMessageContent)}.`);
  logger.log(LogLevel.Trace, "($transportName transport) sending data.");

  //final responseType = content is String ? "arraybuffer" : "text";
  SignalRHttpRequest req = SignalRHttpRequest(content: content, headers: headers);
  final response = await httpClient.post(url, options: req);

  logger.log(LogLevel.Trace, "($transportName transport) request complete. Response status: ${response.statusCode}.");
}
