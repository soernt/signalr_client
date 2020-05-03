import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'dartio_http_client.dart';
import 'errors.dart';
import 'http_connection_options.dart';
import 'iconnection.dart';
import 'ihub_protocol.dart';
import 'itransport.dart';
import 'long_polling_transport.dart';
import 'server_sent_events_transport.dart';
import 'signalr_http_client.dart';
import 'utils.dart';
import 'web_socket_transport.dart';

enum ConnectionState {
  Connecting,
  Connected,
  Disconnected,
}

class NegotiateResponse {
  // Properties
  String connectionId;
  List<AvailableTransport> availableTransports;
  final String url;
  final String accessToken;
  final String error;

  bool get hasConnectionId => !isStringEmpty(connectionId);

  bool get isConnectionResponse =>
      hasConnectionId && !isListEmpty(availableTransports);

  bool get isRedirectResponse => !isStringEmpty(url);

  bool get isErrorResponse => !isStringEmpty(error);

  bool get hasAccessToken => !isStringEmpty(accessToken);

  // Methods

  NegotiateResponse(this.connectionId, this.availableTransports, this.url,
      this.accessToken, this.error);

  NegotiateResponse.fromJson(Map<String, dynamic> json)
      : assert(json != null),
        this.connectionId = json['connectionId'],
        this.url = json['url'],
        this.accessToken = json['accessToken'],
        this.error = json['error'] {
    availableTransports = [];
    final List<dynamic> transports = json['availableTransports'];
    if (transports == null) {
      return;
    }

    for (var i = 0; i < transports.length; i++) {
      availableTransports.add(AvailableTransport.fromJson(transports[i]));
    }
  }
}

class AvailableTransport {
  // Properties

  HttpTransportType transport;
  List<TransferFormat> transferFormats;

  // Methods

  AvailableTransport(this.transport, this.transferFormats);

  AvailableTransport.fromJson(Map<String, dynamic> json) {
    transferFormats = [];

    if (json == null) {
      return;
    }

    transport = httpTransportTypeFromString(json['transport']);
    List<dynamic> formats = json['transferFormats'];
    if (formats == null) {
      return;
    }
    for (var i = 0; i < formats.length; i++) {
      transferFormats.add(getTransferFormatFromString(formats[i]));
    }
  }
}

class HttpConnection implements IConnection {
  // Properties
  static final maxRedirects = 100;

  ConnectionState connectionState;
  String _baseUrl;
  SignalRHttpClient _httpClient;
  final Logger _logger;
  HttpConnectionOptions _options;
  ITransport _transport;
  Future<void> _startPromise;
  Exception _stopError;
  AccessTokenFactory _accessTokenFactory;

  ConnectionFeatures features;

  @override
  OnReceive onreceive;

  @override
  OnClose onclose;

  // Methods

  HttpConnection(String url, {HttpConnectionOptions options})
      : assert(url != null),
        _logger = options?.logger {
    _baseUrl = url;

    _options = options ?? HttpConnectionOptions();
    _httpClient = options.httpClient ?? DartIOHttpClient(_logger);
    connectionState = ConnectionState.Disconnected;
  }

  @override
  Future<void> start({TransferFormat transferFormat}) {
    transferFormat = transferFormat ?? TransferFormat.Binary;

    _logger
        ?.finer("Starting connection with transfer format '$transferFormat'.");

    if (connectionState != ConnectionState.Disconnected) {
      return Future.error(GeneralError(
          "Cannot start a connection that is not in the 'Disconnected' state."));
    }

    connectionState = ConnectionState.Connecting;

    _startPromise = _startInternal(transferFormat);
    return _startPromise;
  }

  @override
  Future<void> send(Object data) {
    if (connectionState != ConnectionState.Connected) {
      return Future.error(GeneralError(
          "Cannot send data if the connection is not in the 'Connected' State."));
    }

    return _transport.send(data);
  }

  @override
  Future<void> stop(Exception error) async {
    connectionState = ConnectionState.Disconnected;
    // Set error as soon as possible otherwise there is a race between
    // the transport closing and providing an error and the error from a close message
    // We would prefer the close message error.
    _stopError = error;

    try {
      await _startPromise;
    } catch (e) {
      // this exception is returned to the user as a rejected Promise from the start method
    }

    // The transport's onclose will trigger stopConnection which will run our onclose event.
    if (_transport != null) {
      await _transport.stop(null);
      _transport = null;
    }
  }

  Future<void> _startInternal(TransferFormat transferFormat) async {
    // Store the original base url and the access token factory since they may change
    // as part of negotiating
    var url = _baseUrl;
    _accessTokenFactory = _options.accessTokenFactory;

    try {
      if (_options.skipNegotiation) {
        if (_options.transport == HttpTransportType.WebSockets) {
          // No need to add a connection ID in this case
          _transport = _constructTransport(HttpTransportType.WebSockets);
          // We should just call connect directly in this case.
          // No fallback or negotiate in this case.
          await _transport?.connect(url, transferFormat);
        } else {
          throw GeneralError(
              "Negotiation can only be skipped when using the WebSocket transport directly.");
        }
      } else {
        NegotiateResponse negotiateResponse;
        var redirects = 0;

        do {
          negotiateResponse = await _getNegotiationResponse(url);
          // the user tries to stop the connection when it is being started
          if (connectionState == ConnectionState.Disconnected) {
            return;
          }

          if (negotiateResponse.isErrorResponse) {
            throw new GeneralError(negotiateResponse.error);
          }

          // if ((negotiateResponse as any).ProtocolVersion) {
          //     throw GeneralError("Detected a connection attempt to an ASP.NET SignalR Server. This client only supports connecting to an ASP.NET Core SignalR Server. See https://aka.ms/signalr-core-differences for details.");
          // }

          if (negotiateResponse.isRedirectResponse) {
            url = negotiateResponse.url;
          }

          if (negotiateResponse.hasAccessToken) {
            // Replace the current access token factory with one that uses
            // the returned access token
            final accessToken = negotiateResponse.accessToken;
            _accessTokenFactory = () => Future<String>.value(accessToken);
          }

          redirects++;
        } while (
            negotiateResponse.isRedirectResponse && redirects < maxRedirects);

        if ((redirects == maxRedirects) &&
            negotiateResponse.isRedirectResponse) {
          throw GeneralError("Negotiate redirection limit exceeded.");
        }

        await _createTransport(
            url, _options.transport, negotiateResponse, transferFormat);
      }

      if (_transport is LongPollingTransport) {
        if (features == null) {
          features = ConnectionFeatures(true);
        } else {
          features.inherentKeepAlive = true;
        }
      }

      _transport?.onReceive = onreceive;
      _transport?.onClose = (e) => _stopConnection(GeneralError(e.toString()));

      // only change the state if we were connecting to not overwrite
      // the state if the connection is already marked as Disconnected
      _changeState(ConnectionState.Connecting, ConnectionState.Connected);
    } catch (e) {
      _logger?.severe("Failed to start the connection: ${e.toString()}");
      connectionState = ConnectionState.Disconnected;
      _transport = null;
      throw e;
    }
  }

  Future<NegotiateResponse> _getNegotiationResponse(String url) async {
    MessageHeaders headers = MessageHeaders();
    if (_accessTokenFactory != null) {
      final token = await _accessTokenFactory();
      if (token != null) {
        headers.setHeaderValue("Authorization", "Bearer $token");
      }
    }

    final negotiateUrl = _resolveNegotiateUrl(url);
    _logger?.finer("Sending negotiation request: $negotiateUrl");
    try {
      final SignalRHttpRequest options =
          SignalRHttpRequest(content: "", headers: headers);
      final response = await _httpClient.post(negotiateUrl, options: options);

      if (response.statusCode != 200) {
        throw GeneralError(
            "Unexpected status code returned from negotiate $response.statusCode");
      }

      if (!(response.content is String)) {
        throw GeneralError("Negotation response content must be a json.");
      }

      return NegotiateResponse.fromJson(
          json.decode(response.content as String));
    } catch (e) {
      _logger?.severe(
          "Failed to complete negotiation with the server: ${e.toString()}");
      throw e;
    }
  }

  Future<void> _createTransport(
      String url,
      Object requestedTransport,
      NegotiateResponse negotiateResponse,
      TransferFormat requestedTransferFormat) async {
    var connectUrl = _createConnectUrl(url, negotiateResponse.connectionId);
    if (requestedTransport is ITransport) {
      _logger?.finer(
          "Connection was provided an instance of ITransport, using that directly.");
      _transport = requestedTransport;
      await _transport.connect(connectUrl, requestedTransferFormat);

      // only change the state if we were connecting to not overwrite
      // the state if the connection is already marked as Disconnected
      _changeState(ConnectionState.Connecting, ConnectionState.Connected);
      return;
    }

    final transports = negotiateResponse.availableTransports;
    for (var endpoint in transports) {
      connectionState = ConnectionState.Connecting;
      final transport = _resolveTransport(
          endpoint, requestedTransport, requestedTransferFormat);
      if (transport == null) {
        continue;
      }
      _transport = _constructTransport(transport);
      if (!negotiateResponse.hasConnectionId) {
        negotiateResponse = await _getNegotiationResponse(url);
        connectUrl = _createConnectUrl(url, negotiateResponse.connectionId);
      }
      try {
        await _transport?.connect(connectUrl, requestedTransferFormat);
        _changeState(ConnectionState.Connecting, ConnectionState.Connected);
        return;
      } catch (ex) {
        _logger?.severe(
            "Failed to start the transport '$transport': ${ex.toString()}");
        connectionState = ConnectionState.Disconnected;
        negotiateResponse.connectionId = null;
      }
    }

    throw new GeneralError(
        "Unable to initialize any of the available transports.");
  }

  ITransport _constructTransport(HttpTransportType transport) {
    switch (transport) {
      case HttpTransportType.WebSockets:
        return WebSocketTransport(
            _accessTokenFactory, _logger, _options.logMessageContent ?? false);
      case HttpTransportType.ServerSentEvents:
        return new ServerSentEventsTransport(_httpClient, _accessTokenFactory,
            _logger, _options.logMessageContent ?? false);
      case HttpTransportType.LongPolling:
        return LongPollingTransport(_httpClient, _accessTokenFactory, _logger,
            _options.logMessageContent ?? false);
      default:
        throw new GeneralError("Unknown transport: $transport.");
    }
  }

  HttpTransportType _resolveTransport(
      AvailableTransport endpoint,
      HttpTransportType requestedTransport,
      TransferFormat requestedTransferFormat) {
    final transport = endpoint.transport;
    if (transport == null) {
      _logger?.finer(
          "Skipping transport '${endpoint.transport}' because it is not supported by this client.");
    } else {
      final transferFormats = endpoint.transferFormats;
      if (transportMatches(requestedTransport, transport)) {
        if (transferFormats.indexOf(requestedTransferFormat) >= 0) {
          _logger?.finer("Selecting transport '$transport'");
          return transport;
        } else {
          _logger?.finer(
              "Skipping transport '$transport' because it does not support the requested transfer format '$requestedTransferFormat'.");
        }
      } else {
        _logger?.finer(
            "Skipping transport '$transport' because it was disabled by the client.");
      }
    }
    return null;
  }

  bool _changeState(ConnectionState from, ConnectionState to) {
    if (connectionState == from) {
      connectionState = to;
      return true;
    }
    return false;
  }

  void _stopConnection(Exception error) {
    _transport = null;

    // If we have a stopError, it takes precedence over the error from the transport
    error = _stopError ?? error;

    if (error != null) {
      _logger?.severe("Connection disconnected with error '$error'.");
    } else {
      _logger?.info("Connection disconnected.");
    }

    connectionState = ConnectionState.Disconnected;

    if (onclose != null) {
      onclose(error);
    }
  }

  static String _createConnectUrl(String url, String connectionId) {
    if (isStringEmpty(connectionId)) {
      return url;
    }
    return url + (url.indexOf("?") == -1 ? "?" : "&") + "id=$connectionId";
  }

  static String _resolveNegotiateUrl(String url) {
    final index = url.indexOf("?");
    var negotiateUrl = url.substring(0, index == -1 ? url.length : index);
    if (negotiateUrl[negotiateUrl.length - 1] != "/") {
      negotiateUrl += "/";
    }
    negotiateUrl += "negotiate";
    negotiateUrl += index == -1 ? "" : url.substring(index);
    return negotiateUrl;
  }

  static bool transportMatches(
      HttpTransportType requestedTransport, HttpTransportType actualTransport) {
    return (requestedTransport == null) ||
        (actualTransport == requestedTransport);
  }
}
