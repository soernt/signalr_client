import 'dart:async';

import 'package:logging/logging.dart';

import 'abort_controller.dart';
import 'errors.dart';
import 'ihub_protocol.dart';
import 'itransport.dart';
import 'signalr_http_client.dart';
import 'utils.dart';

class LongPollingTransport implements ITransport {
  // Properties
  final SignalRHttpClient _httpClient;
  final AccessTokenFactory _accessTokenFactory;
  final Logger _logger;
  final bool _logMessageContent;
  final AbortController _pollAbort;

  bool get pollAborted => _pollAbort.aborted;

  String _url;
  bool _running;
  Future<void> _receiving;
  Exception _closeError;

  @override
  OnClose onClose;

  @override
  OnReceive onReceive;

  // Methods

  LongPollingTransport(
      SignalRHttpClient httpClient,
      AccessTokenFactory accessTokenFactory,
      Logger logger,
      bool logMessageContent)
      : assert(httpClient != null),
        _httpClient = httpClient,
        _accessTokenFactory = accessTokenFactory,
        _logger = logger,
        _logMessageContent = logMessageContent,
        _pollAbort = AbortController() {
    _running = false;
  }

  @override
  Future<void> connect(String url, TransferFormat transferFormat) async {
    assert(!isStringEmpty(url));
    assert(transferFormat != null);

    _url = url;

    _logger?.finest("(LongPolling transport) Connecting");

    if (transferFormat == TransferFormat.Binary) {
      throw new GeneralError(
          "Binary protocols via Long Polling Transport is not supported.");
    }

    final pollOptions = SignalRHttpRequest(
        abortSignal: _pollAbort.signal,
        headers: MessageHeaders(),
        timeout: 100000);

    final token = await _getAccessToken();
    _updateHeaderToken(pollOptions, token);

    // Make initial long polling request
    // Server uses first long polling request to finish initializing connection and it returns without data
    final pollUrl = "$_url&_=${DateTime.now()}";
    _logger?.finest("(LongPolling transport) polling: $pollUrl");
    final response = await _httpClient.get(pollUrl, options: pollOptions);
    if (response.statusCode != 200) {
      _logger?.severe(
          "(LongPolling transport) Unexpected response code: ${response.statusCode}");

      // Mark running as false so that the poll immediately ends and runs the close logic
      _closeError = HttpError(response.statusText ?? "", response.statusCode);
      _running = false;
    } else {
      _running = true;
    }

    _receiving = poll(_url, pollOptions);
  }

  Future<void> poll(String url, SignalRHttpRequest pollOptions) async {
    try {
      while (_running) {
        // We have to get the access token on each poll, in case it changes
        final token = await _getAccessToken();
        _updateHeaderToken(pollOptions, token);

        try {
          final pollUrl = "$url&_=${DateTime.now()}";
          _logger?.finest("(LongPolling transport) polling: $pollUrl");
          final response = await _httpClient.get(pollUrl, options: pollOptions);

          if (response.statusCode == 204) {
            _logger?.info("(LongPolling transport) Poll terminated by server");

            _running = false;
          } else if (response.statusCode != 200) {
            _logger?.severe(
                "(LongPolling transport) Unexpected response code: ${response.statusCode}");

            // Unexpected status code
            _closeError =
                HttpError(response.statusText ?? "", response.statusCode);
            _running = false;
          } else {
            // Process the response
            if (!isStringEmpty(response.content)) {
              // _logger.log(LogLevel.Trace, "(LongPolling transport) data received. ${getDataDetail(response.content, this.logMessageContent)}");
              _logger?.finest("(LongPolling transport) data received");
              if (onReceive != null) {
                onReceive(response.content);
              }
            } else {
              // This is another way timeout manifest.
              _logger?.finest(
                  "(LongPolling transport) Poll timed out, reissuing.");
            }
          }
        } catch (e) {
          if (!_running) {
            // Log but disregard errors that occur after stopping
            _logger?.finest(
                "(LongPolling transport) Poll errored after shutdown: ${e.message}");
          } else {
            if (e is TimeoutError) {
              // Ignore timeouts and reissue the poll.
              _logger?.finest(
                  "(LongPolling transport) Poll timed out, reissuing.");
            } else {
              // Close the connection with the error as the result.
              _closeError = e;
              _running = false;
            }
          }
        }
      }
    } finally {
      _logger?.finest("(LongPolling transport) Polling complete.");

      // We will reach here with pollAborted==false when the server returned a response causing the transport to stop.
      // If pollAborted==true then client initiated the stop and the stop method will raise the close event after DELETE is sent.
      if (!this.pollAborted) {
        _raiseOnClose();
      }
    }
  }

  @override
  Future<void> send(Object data) async {
    if (!_running) {
      return Future.error(
          new GeneralError("Cannot send until the transport is connected"));
    }
    await sendMessage(_logger, "LongPolling", _httpClient, _url,
        _accessTokenFactory, data, _logMessageContent);
  }

  @override
  Future<void> stop(Error error) async {
    _logger?.finest("(LongPolling transport) Stopping polling.");

    // Tell receiving loop to stop, abort any current request, and then wait for it to finish
    _running = false;
    _pollAbort.abort();

    try {
      await _receiving;

      // Send DELETE to clean up long polling on the server
      _logger
          ?.finest("(LongPolling transport) sending DELETE request to $_url.");

      final deleteOptions = SignalRHttpRequest();
      final token = await _getAccessToken();
      _updateHeaderToken(deleteOptions, token);
      await _httpClient.delete(_url, options: deleteOptions);

      _logger?.finest("(LongPolling transport) DELETE request sent.");
    } finally {
      _logger?.finest("(LongPolling transport) Stop finished.");

      // Raise close event here instead of in polling
      // It needs to happen after the DELETE request is sent
      _raiseOnClose();
    }
  }

  Future<String> _getAccessToken() async {
    if (_accessTokenFactory != null) {
      return await _accessTokenFactory();
    }
    return null;
  }

  void _updateHeaderToken(SignalRHttpRequest request, String token) {
    if (request.headers == null) {
      request.headers = MessageHeaders();
    }

    if (!isStringEmpty(token)) {
      request.headers.setHeaderValue("Authorization", "Bearer $token");
      return;
    }
    request.headers.removeHeader("Authorization");
  }

  void _raiseOnClose() {
    if (onClose != null) {
      var logMessage = "(LongPolling transport) Firing onclose event.";
      if (_closeError != null) {
        logMessage += " Error: " + _closeError.toString();
      }
      _logger?.finest(logMessage);
      onClose(new GeneralError(_closeError?.toString()));
    }
  }
}
