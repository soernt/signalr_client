import 'dart:async';
import 'package:http/http.dart';
import 'errors.dart';
import 'signalr_http_client.dart';
import 'utils.dart';
import 'package:logging/logging.dart';
import 'clients/http_client_default.dart'
    if (dart.library.js) 'clients/http_client_browser.dart';

typedef OnHttpClientCreateCallback = void Function(Client httpClient);

class WebSupportingHttpClient extends SignalRHttpClient {
  // Properties

  final Logger _logger;
  final OnHttpClientCreateCallback _httpClientCreateCallback;

  // Methods

  WebSupportingHttpClient(Logger logger,
      {OnHttpClientCreateCallback httpClientCreateCallback})
      : this._logger = logger,
        this._httpClientCreateCallback = httpClientCreateCallback;

  Future<SignalRHttpResponse> send(SignalRHttpRequest request) {
    // Check that abort was not signaled before calling send
    if ((request.abortSignal != null) && request.abortSignal.aborted) {
      return Future.error(AbortError());
    }

    if ((request.method == null) || (request.method.length == 0)) {
      return Future.error(new ArgumentError("No method defined."));
    }

    if ((request.url == null) || (request.url.length == 0)) {
      return Future.error(new ArgumentError("No url defined."));
    }

    return Future<SignalRHttpResponse>(() async {
      final uri = Uri.parse(request.url);

      final httpClient = clientWithWebSupport;
      if (_httpClientCreateCallback != null) {
        _httpClientCreateCallback(httpClient);
      }

      final abortFuture = Future<void>(() {
        final completer = Completer<void>();
        if (request.abortSignal != null) {
          request.abortSignal.onabort =
              () => completer.completeError(AbortError());
        }
        return completer.future;
      });

      _logger?.finest(
          "HTTP send: url '${request.url}', method: '${request.method}' content: '${request.content}'");

      Map<String, String> headers = {
        'X-Requested-With': 'FlutterHttpClient',
        'Content-Type': 'text/plain;charset=UTF-8',
      };

      if ((request.headers != null) && (!request.headers.isEmtpy)) {
        for (var name in request.headers.names) {
          headers[name] = request.headers.getHeaderValue(name);
        }
      }

      final httpRespFuture = await Future.any(
          [_sendHttpRequest(httpClient, request, uri, headers), abortFuture]);
      final httpResp = httpRespFuture as Response;
      if (httpResp == null) {
        return Future.value(null);
      }

      if (request.abortSignal != null) {
        request.abortSignal.onabort = null;
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
          if (isStringEmpty(uri.queryParameters['id'])) {
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
    Map<String, String> headers,
  ) {
    Future<Response> httpResponse;

    switch (request.method.toLowerCase()) {
      case 'post':
        httpResponse =
            httpClient.post(uri, body: request.content, headers: headers);
        break;
      case 'put':
        httpResponse =
            httpClient.put(uri, body: request.content, headers: headers);
        break;
      case 'delete':
        httpResponse =
            httpClient.delete(uri, body: request.content, headers: headers);
        break;
      case 'get':
      default:
        httpResponse = httpClient.get(uri, headers: headers);
    }

    final hasTimeout = (request.timeout != null) && (0 < request.timeout);
    if (hasTimeout) {
      httpResponse =
          httpResponse.timeout(Duration(milliseconds: request.timeout));
    }

    return httpResponse;
  }
}
