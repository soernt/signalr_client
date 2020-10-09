import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'errors.dart';
import 'signalr_http_client.dart';
import 'utils.dart';
import 'package:logging/logging.dart';

class DartIOHttpClient extends SignalRHttpClient {
  // Properties

  final Logger _logger;

  // Methods

  DartIOHttpClient(Logger logger) : this._logger = logger;

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

      final httpClient = new HttpClient();

      final abortFuture = Future<void>(() {
        final completer = Completer<void>();
        if (request.abortSignal != null) {
          request.abortSignal.onabort =
              () => completer.completeError(AbortError());
        }
        return completer.future;
      });

      if ((request.timeout != null) && (0 < request.timeout)) {
        httpClient.connectionTimeout = Duration(milliseconds: request.timeout);
      }

      _logger?.finest(
          "HTTP send: url '${request.url}', method: '${request.method}' content: '${request.content}'");

      final httpReqFuture = await Future.any(
          [httpClient.openUrl(request.method, uri), abortFuture]);
      final httpReq = httpReqFuture as HttpClientRequest;
      if (httpReq == null) {
        return Future.value(null);
      }

      httpReq.headers.set("X-Requested-With", "FlutterHttpClient");
      httpReq.headers.set("Content-Type", "text/plain;charset=UTF-8");
      if ((request.headers != null) && (!request.headers.isEmtpy)) {
        for (var name in request.headers.names) {
          httpReq.headers.set(name, request.headers.getHeaderValue(name));
        }
      }

      if (request.content != null) {
        httpReq.write(request.content);
      }

      final httpRespFuture = await Future.any([httpReq.close(), abortFuture]);
      final httpResp = httpRespFuture as HttpClientResponse;
      if (httpResp == null) {
        return Future.value(null);
      }

      if (request.abortSignal != null) {
        request.abortSignal.onabort = null;
      }

      if ((httpResp.statusCode >= 200) && (httpResp.statusCode < 300)) {
        Object content;
        final contentTypeHeader = httpResp.headers["Content-Type"];
        final isJsonContent = contentTypeHeader.indexWhere((header) => header.startsWith("application/json")) != -1;
        if (isJsonContent) {
          content = await utf8.decoder.bind(httpResp).join();
        } else {
          content = await utf8.decoder.bind(httpResp).join();
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
}
