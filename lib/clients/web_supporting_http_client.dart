import 'dart:async';

import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/protocols/ihub_protocol.dart';

import '../exceptions/errors.dart';
import '../utils/utils.dart';
import 'signalr_http_client.dart';

typedef OnHttpClientCreateCallback = void Function(Client httpClient);

class WebSupportingHttpClient with SignalRHttpClient {
  // Properties

  final Logger _logger;
  final OnHttpClientCreateCallback? _httpClientCreateCallback;

  // Methods
  const WebSupportingHttpClient(Logger logger,
      {OnHttpClientCreateCallback? httpClientCreateCallback})
      : this._logger = logger,
        this._httpClientCreateCallback = httpClientCreateCallback;

  Future<SignalRHttpResponse> send(SignalRHttpRequest request) {
    // Check that abort was not signaled before calling send
    if ((request.abortSignal != null) && request.abortSignal!.aborted!) {
      return Future.error(AbortError());
    }

    if (request.method?.isEmpty ?? true) {
      return Future.error(new ArgumentError("No method defined."));
    }

    if (request.url?.isEmpty ?? true) {
      return Future.error(new ArgumentError("No url defined."));
    }

    return Future<SignalRHttpResponse>(() async {
      final uri = Uri.parse(request.url!);

      final httpClient = Client();

      if (_httpClientCreateCallback != null) {
        _httpClientCreateCallback!(httpClient);
      }

      final abortFuture = Future<void>(() {
        final completer = Completer<void>();
        if (request.abortSignal != null) {
          request.abortSignal!.onabort = () {
            if (!completer.isCompleted) completer.completeError(AbortError());
          };
        }
        return completer.future;
      });

      final isJson = request.content != null &&
          request.content is String &&
          (request.content as String).startsWith('{');

      var headers = MessageHeaders();

      headers["X-Requested-With"] = 'FlutterHttpClient';
      headers["content"] = isJson
          ? 'application/json;charset=UTF-8'
          : 'text/plain;charset=UTF-8';

      if ((request.headers != null) && (!request.headers!.isEmpty)) {
        for (var name in request.headers!.names) {
          headers[name] = request.headers![name] ?? "";
        }
      }

      _logger.finest(
          "HTTP send: url '${request.url}', method: '${request.method}' content: '${request.content}' content length = '${(request.content as String).length}' headers: '$headers'");

      final httpRespFuture = await Future.any(
          [_sendHttpRequest(httpClient, request, uri, headers), abortFuture]);
      final httpResp = httpRespFuture as Response;

      if (request.abortSignal != null) {
        request.abortSignal!.onabort = null;
      }

      if ((httpResp.statusCode >= 200) && (httpResp.statusCode < 300)) {
        Object content;
        final contentTypeHeader = httpResp.headers['content-type'];
        final isJsonContent = contentTypeHeader == null ||
            contentTypeHeader.startsWith('application/json');
        if (isJsonContent) {
          content = httpResp.body;
        } else {
          content = httpResp.body;
          // When using SSE and the uri has an 'id' query parameter the response is not evaluated, otherwise it is an error.
          if (uri.queryParameters['id'].isNullOrEmpty) {
            throw ArgumentError(
                "Response Content-Type not supported: $contentTypeHeader");
          }
        }

        return SignalRHttpResponse(httpResp.statusCode,
            statusText: httpResp.reasonPhrase, content: content);
      } else {
        throw HttpError(httpResp.reasonPhrase, httpResp.statusCode);
      }
    });
  }

  Future<Response> _sendHttpRequest(
    Client httpClient,
    SignalRHttpRequest request,
    Uri uri,
    MessageHeaders headers,
  ) {
    Future<Response> httpResponse;

    switch (request.method?.toLowerCase()) {
      case 'post':
        httpResponse =
            httpClient.post(uri, body: request.content, headers: headers.asMap);
        break;
      case 'put':
        httpResponse =
            httpClient.put(uri, body: request.content, headers: headers.asMap);
        break;
      case 'delete':
        httpResponse = httpClient.delete(uri,
            body: request.content, headers: headers.asMap);
        break;
      case 'get':
      default:
        httpResponse = httpClient.get(uri, headers: headers.asMap);
    }

    final hasTimeout = (request.timeout != null) && (0 < request.timeout!);
    if (hasTimeout) {
      httpResponse =
          httpResponse.timeout(Duration(milliseconds: request.timeout!));
    }

    return httpResponse;
  }
}
