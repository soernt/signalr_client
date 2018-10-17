import 'dart:async';

import 'package:w3c_event_source/event_source.dart';

import 'errors.dart';
import 'ilogger.dart';
import 'itransport.dart';
import 'signalr_http_client.dart';
import 'utils.dart';


class ServerSentEventsTransport implements ITransport {
  // Properties
  final SignalRHttpClient _httpClient;
  final AccessTokenFactory _accessTokenFactory;

  final ILogger _logger;
  final bool _logMessageContent;
  EventSource _eventSource;
  StreamSubscription<MessageEvent> _eventSourceSub;
  String _url;

  @override
  OnClose onClose;

  @override
  OnReceive onReceive;

  ServerSentEventsTransport(SignalRHttpClient httpClient, AccessTokenFactory accessTokenFactory, ILogger logger, bool logMessageContent)
      : assert(httpClient != null),
        _httpClient = httpClient,
        _accessTokenFactory = accessTokenFactory,
        _logger = logger,
        _logMessageContent = logMessageContent;

  // Methods
  @override
  Future<void> connect(String url, TransferFormat transferFormat) async {
    assert(!isStringEmpty(url));
    assert(transferFormat != null);
    _logger.log(LogLevel.Trace, "(SSE transport) Connecting");

    // set url before accessTokenFactory because this.url is only for send and we set the auth header instead of the query string for send
    _url = url;

    if (_accessTokenFactory != null) {
      final token = await _accessTokenFactory();
      if (!isStringEmpty(token)) {
        final encodedToken = Uri.encodeComponent(token);
        url += (url.indexOf("?") < 0 ? "?" : "&") + "access_token=$encodedToken";
      }
    }

    var opened = false;
    if (transferFormat != TransferFormat.Text) {
      Future.error(GeneralError("The Server-Sent Events transport only supports the 'Text' transfer format"));
    }

    _eventSource = EventSource(Uri.parse(url));

    _eventSourceSub = _eventSource.events.listen((MessageEvent event) {
      if (onReceive != null) {
        try {
          //_logger.log(LogLevel.Trace, "(SSE transport) data received. ${getDataDetail(e.data, this.logMessageContent)}.`);
          _logger.log(LogLevel.Trace, "(SSE transport) data received");
          onReceive(event.data);
        } catch (error) {
          _close(error);
          return;
        }
      }
    }, onError: (Object error) {
      if (opened) {
        _close(error);
      }
    }, onDone: () {
      _close(null);
    });
  }

  @override
  Future<void> send(Object data) async {
    if (_eventSource == null) {
      return Future.error(new GeneralError("Cannot send until the transport is connected"));
    }
    await sendMessage(_logger, "SSE", _httpClient, _url, _accessTokenFactory, data, _logMessageContent);
  }

  @override
  Future<void> stop(Error error) {
    _close(error);
    return Future.value(null);
  }

  _close(Error error) {
    if (_eventSourceSub != null) {
      _eventSourceSub.cancel();
      _eventSource = null;

      if (onClose != null) {
        Exception ex;
        if (error != null) {
          ex = (error is Exception) ? error : new GeneralError(error?.toString());
        }
        onClose(ex);
      }
    }
  }
}
