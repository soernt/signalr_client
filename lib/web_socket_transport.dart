import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'errors.dart';
import 'itransport.dart';
import 'utils.dart';

class WebSocketTransport implements ITransport {
  // Properties

  Logger _logger;
  AccessTokenFactory _accessTokenFactory;
  bool _logMessageContent;
  WebSocket _webSocket;
  StreamSubscription<Object> _webSocketListenSub;

  @override
  OnClose onClose;

  @override
  OnReceive onReceive;

  // Methods
  WebSocketTransport(AccessTokenFactory accessTokenFactory, Logger logger,
      bool logMessageContent)
      : this._accessTokenFactory = accessTokenFactory,
        this._logger = logger,
        this._logMessageContent = logMessageContent;

  @override
  Future<void> connect(String url, TransferFormat transferFormat) async {
    assert(url != null);
    assert(transferFormat != null);

    _logger?.finest("(WebSockets transport) Connecting");

    if (_accessTokenFactory != null) {
      final token = await _accessTokenFactory();
      if (!isStringEmpty(token)) {
        final encodedToken = Uri.encodeComponent(token);
        url +=
            (url.indexOf("?") < 0 ? "?" : "&") + "access_token=$encodedToken";
      }
    }

    var websocketCompleter = Completer();
    var opened = false;
    url = url.replaceFirst('http', 'ws');
    _logger?.finest("WebSocket try connecting to '$url'.");
    _webSocket = await WebSocket.connect(url);
    opened = true;
    websocketCompleter.complete();
    _logger?.info("WebSocket connected to '$url'.");
    _webSocketListenSub = _webSocket.listen(
      // onData
      (Object message) {
        if (_logMessageContent && message is String) {
          _logger?.finest("(WebSockets transport) data received. message ${getDataDetail(message, _logMessageContent)}.");
        } else {
          _logger?.finest("(WebSockets transport) data received.");
        }
        if (onReceive != null) {
          try {
            onReceive(message);
          } catch (error) {
            _close();
          }
        }
      },

      // onError
      onError: (Object error) {
        var e = error != null ? error : "Unknown websocket error";
        websocketCompleter.completeError(e);
      },

      // onDone
      onDone: () {
        // Don't call close handler if connection was never established
        // We'll reject the connect call instead
        if (opened) {
          if (onClose != null) {
            onClose();
          }
        } else {
          websocketCompleter.completeError("There was an error with the transport.");
        }
      },
    );

    return websocketCompleter.future;
  }

  @override
  Future<void> send(Object data) {
    if ((_webSocket != null) && (_webSocket.readyState == WebSocket.open)) {
      _logger?.finest("(WebSockets transport) sending data. ${getDataDetail(data, true)}.");
      //_logger?.finest("(WebSockets transport) sending data.");

      if (data is String) {
        _webSocket.add(data);
      } else if (data is Uint8List) {
        _webSocket.add(data);
      } else {
        throw GeneralError("Content type is not handled.");
      }

      return Future.value(null);
    }

    return Future.error(GeneralError("WebSocket is not in the OPEN state"));
  }

  @override
  Future<void> stop() async {
    await _close();
    return Future.value(null);
  }

  _close() async {
    if (_webSocket != null) {
      // Clear websocket handlers because we are considering the socket closed now
      if (_webSocketListenSub != null) {
        await _webSocketListenSub.cancel();
        _webSocketListenSub = null;
      }
      _webSocket.close();
      _webSocket = null;
    }

    _logger?.finest("(WebSockets transport) socket closed.");
    if (onClose != null) {
      onClose();
    }
  }
}
