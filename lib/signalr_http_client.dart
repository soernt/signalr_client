import 'dart:async';

import 'abort_controller.dart';
import 'ihub_protocol.dart';

/// Represents an HTTP request.
class SignalRHttpRequest {
  // Properties

  /// The HTTP method to use for the request.
  String? method;

  /// The URL for the request.
  String? url;

  ///The body content for the request. May be a string or an ArrayBuffer (for binary data).
  Object? content;

  ///An object describing headers to apply to the request.
  MessageHeaders? headers;

  // /** The XMLHttpRequestResponseType to apply to the request. */
  // responseType?: XMLHttpRequestResponseType;

  /// An AbortSignal that can be monitored for cancellation.
  IAbortSignal? abortSignal;

  ///The time to wait for the request to complete before throwing a TimeoutError. Measured in milliseconds.
  int? timeout;

  // Methods

  SignalRHttpRequest(
      {String? method,
      String? url,
      Object? content,
      MessageHeaders? headers,
      IAbortSignal? abortSignal,
      int? timeout})
      : this.method = method,
        this.url = url,
        this.content = content,
        this.headers = headers,
        this.abortSignal = abortSignal,
        this.timeout = timeout;
}

/// Represents an HTTP response.
class SignalRHttpResponse {
  // Properties

  /// The status code of the response.
  final int statusCode;

  /// The status message of the response
  final String? statusText;

  /// May be a string (json) or an Uint8List (binary)
  final Object? content;

  //Methods

  ///Constructs a new instance of HttpResponse with the specified status code.
  ///
  /// statusCode: The status code of the response.
  /// statusText: The status message of the response.
  /// content: The content of the response
  ///
  SignalRHttpResponse(int statusCode,
      {String? statusText = '', Object? content})
      : this.statusCode = statusCode,
        this.statusText = statusText,
        this.content = content;
}

/// Abstraction over an HTTP client.
///
/// This class provides an abstraction over an HTTP client so that a different implementation can be provided on different platforms.
///
abstract class SignalRHttpClient {
  /// Issues an HTTP GET request to the specified URL, returning a Promise that resolves with an {@link @microsoft/signalr.HttpResponse} representing the result.
  ///
  /// url The URL for the request.
  /// HttpRequest options Additional options to configure the request. The 'url' field in this object will be overridden by the url parameter.
  /// Returns a Future<HttpResponse> that resolves with an HttpResponse describing the response, or rejects with an Error indicating a failure.
  ///
  Future<SignalRHttpResponse> get(String url,
      {required SignalRHttpRequest options}) {
    options.method = 'GET';
    options.url = url;
    return send(options);
  }

  /// Issues an HTTP POST request to the specified URL, returning a Promise that resolves with an {@link @microsoft/signalr.HttpResponse} representing the result.
  ///
  /// url: The URL for the request.
  /// options: Additional options to configure the request. The 'url' field in this object will be overridden by the url parameter.
  /// Returns a Future that resolves with an describing the response, or rejects with an Error indicating a failure.
  ///
  Future<SignalRHttpResponse> post(String? url,
      {required SignalRHttpRequest options}) {
    options.method = 'POST';
    options.url = url;
    return send(options);
  }

  ///Issues an HTTP DELETE request to the specified URL, returning a Promise that resolves with an {@link @microsoft/signalr.HttpResponse} representing the result.
  ///
  /// The URL for the request.
  /// Additional options to configure the request. The 'url' field in this object will be overridden by the url parameter.
  /// Returns a Future that resolves with an describing the response, or rejects with an Error indicating a failure.
  ///
  Future<SignalRHttpResponse> delete(String? url,
      {required SignalRHttpRequest options}) {
    options.method = 'DELETE';
    options.url = url;
    return send(options);
  }

  ///Issues an HTTP request to the specified URL, returning a Future that resolves with an SignalRHttpResponse representing the result.
  ///
  /// request: An HttpRequest describing the request to send.
  /// Returns a Future that resolves with an SignalRHttpResponse describing the response, or rejects with an Error indicating a failure.
  ///
  Future<SignalRHttpResponse> send(SignalRHttpRequest request);
}
