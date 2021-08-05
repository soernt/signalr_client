import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sse_client/sse_client.dart';

import '../../clients/signalr_http_client.dart';
import '../../exceptions/errors.dart';
import '../../utils/utils.dart';
import '../itransport.dart';

class ServerSentEventsTransport implements ITransport {
  // Properties
  final SignalRHttpClient _httpClient;
  final AccessTokenFactory? _accessTokenFactory;

  final Logger? _logger;
  final bool _logMessageContent;
  SseClient? _sseClient;
  String? _url;

  @override
  OnClose? onClose;

  @override
  OnReceive? onReceive;

  ServerSentEventsTransport(
      SignalRHttpClient httpClient,
      AccessTokenFactory? accessTokenFactory,
      Logger? logger,
      bool logMessageContent)
      : _httpClient = httpClient,
        _accessTokenFactory = accessTokenFactory,
        _logger = logger,
        _logMessageContent = logMessageContent;

  // Methods
  @override
  Future<void> connect(String url, TransferFormat transferFormat) async {
    assert(url.isNotEmpty);
    _logger?.finest("(SSE transport) Connecting");

    // set url before accessTokenFactory because this.url is only for send and we set the auth header instead of the query string for send
    _url = url;

    if (_accessTokenFactory != null) {
      final token = await _accessTokenFactory!();
      if (token.isNotNullOrEmpty) {
        final encodedToken = Uri.encodeComponent(token);
        url +=
            (url.indexOf("?") < 0 ? "?" : "&") + "access_token=$encodedToken";
      }
    }

    var opened = false;
    if (transferFormat != TransferFormat.Text) {
      return Future.error(GeneralError(
          "The Server-Sent Events transport only supports the 'Text' transfer format"));
    }

    SseClient client;
    try {
      client = SseClient.connect(Uri.parse(_url!));
      _logger?.finer('(SSE transport) connected to $_url');
      opened = true;
      _sseClient = client;
    } catch (e) {
      return Future.error(e);
    }

    _sseClient!.stream!.listen((data) {
      if (onReceive != null) {
        try {
          _logger?.finest(
              '(SSE transport) data received. ${getDataDetail(data, _logMessageContent)}.');
          onReceive!(data);
        } catch (error) {
          _close(error: error);
          return;
        }
      }
    }, onError: (e) {
      _logger?.severe('(SSE transport) error when listening to stream: $e');
      if (opened) {
        _close(error: e);
      }
    });
  }

  @override
  Future<void> send(Object data) async {
    if (_sseClient == null) {
      return Future.error(
          new GeneralError("Cannot send until the transport is connected"));
    }
    await sendMessage(
      _logger,
      "SSE",
      _httpClient,
      _url!,
      _accessTokenFactory,
      data,
      _logMessageContent,
    );
  }

  @override
  Future<void> stop() {
    _close();
    return Future.value(null);
  }

  _close({dynamic error}) {
    if (_sseClient != null) {
      _sseClient = null;

      if (onClose != null) {
        Exception? ex;
        if (error != null) {
          ex = (error is Exception)
              ? error
              : new GeneralError(error?.toString());
        }
        onClose!(error: ex);
      }
    }
  }
}
