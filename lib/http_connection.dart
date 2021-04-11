import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  Disconnecting,
}

class NegotiateResponse {
  // Properties
  String connectionId;
  String connectionToken;
  int negotiateVersion;
  List<AvailableTransport> availableTransports;
  final String url;
  final String accessToken;
  final String error;

  bool get hasConnectionId => !isStringEmpty(connectionId);

  bool get hasConnectionTokenId => !isStringEmpty(connectionToken);

  bool get hasNegotiateVersion => !isIntEmpty(negotiateVersion);

  bool get isConnectionResponse =>
      hasConnectionId && !isListEmpty(availableTransports);

  bool get isRedirectResponse => !isStringEmpty(url);

  bool get isErrorResponse => !isStringEmpty(error);

  bool get hasAccessToken => !isStringEmpty(accessToken);

  // Methods

  NegotiateResponse(
      this.connectionId,
      this.connectionToken,
      this.negotiateVersion,
      this.availableTransports,
      this.url,
      this.accessToken,
      this.error);

  NegotiateResponse.fromJson(Map<String, dynamic> json)
      : assert(json != null),
        this.connectionId = json['connectionId'],
        this.connectionToken = json['connectionToken'],
        this.negotiateVersion = json['negotiateVersion'],
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

class TransportSendQueue {
  List<Object> _buffer = [];
  Completer _sendBufferedData;
  bool _executing = true;
  Completer _transportResult;
  Future<void> _sendLoopPromise;
  final ITransport transport;

  TransportSendQueue(this.transport) {
    _sendBufferedData = Completer();
    _transportResult = Completer();

    _sendLoopPromise = _sendLoop();
  }

  Future<void> send(Object data) {
    _bufferData(data);
    if (_transportResult == null) {
      _transportResult = Completer();
    }

    return _transportResult.future;
  }

  Future<void> stop() {
    _executing = false;
    _sendBufferedData.complete();
    return _sendLoopPromise;
  }

  _bufferData(Object data) {
    if (data is Uint8List && _buffer.length > 0 && !(_buffer[0] is Uint8List)) {
      throw GeneralError(
          "Expected data to be of type ${_buffer[0].runtimeType} but got Uint8List");
    } else if (data is String &&
        _buffer.length > 0 &&
        !(_buffer[0] is String)) {
      throw GeneralError(
          "Expected data to be of type ${_buffer[0].runtimeType} but got String");
    }

    _buffer.add(data);
    _sendBufferedData.complete();
  }

  Future<void> _sendLoop() async {
    while (true) {
      await _sendBufferedData.future;

      if (!_executing) {
        if (_transportResult != null) {
          _transportResult.completeError("Connection stopped.");
        }

        break;
      }

      _sendBufferedData = Completer();

      var transportResult = _transportResult;
      _transportResult = null;

      var data = _buffer[0] is String
          ? _buffer.join("")
          : TransportSendQueue.concatBuffers(_buffer);

      _buffer.length = 0;

      try {
        await this.transport.send(data);
        transportResult.complete();
      } catch (error) {
        transportResult.completeError(error);
      }
    }
  }

  static Uint8List concatBuffers(List<Uint8List> arrayBuffers) {
    var totalLength =
        arrayBuffers.map((b) => b.lengthInBytes).reduce((a, b) => a + b);
    var result = Uint8List(totalLength);
    var offset = 0;
    for (var item in arrayBuffers) {
      result.setAll(offset, item);
      offset += item.lengthInBytes;
    }
    return result;
  }
}

class HttpConnection implements IConnection {
  // Properties
  static final maxRedirects = 100;
  static final maxRequestTimeoutMilliseconds = 2000;

  ConnectionState _connectionState;
  // connectionStarted is tracked independently from connectionState, so we can check if the
  // connection ever did successfully transition from connecting to connected before disconnecting.
  bool _connectionStarted;
  SignalRHttpClient _httpClient;
  final Logger _logger;
  HttpConnectionOptions _options;
  ITransport _transport;
  Future<void> _startInternalPromise;
  Future<void> _stopPromise;
  Completer _stopPromiseCompleter;
  Exception _stopError;
  AccessTokenFactory _accessTokenFactory;
  TransportSendQueue _sendQueue;

  ConnectionFeatures features;
  String baseUrl;
  String connectionId;

  @override
  OnReceive onreceive;

  @override
  OnClose onclose;

  int _negotiateVersion = 1;

  // Methods

  HttpConnection(String url, {HttpConnectionOptions options})
      : assert(url != null),
        _logger = options?.logger {
    baseUrl = url;

    _options = options ?? HttpConnectionOptions();
    _httpClient = options.httpClient ?? DartIOHttpClient(_logger);
    _connectionState = ConnectionState.Disconnected;
    _connectionStarted = false;
  }

  @override
  Future<void> start({TransferFormat transferFormat}) async {
    transferFormat = transferFormat ?? TransferFormat.Binary;

    _logger
        ?.finer("Starting connection with transfer format '$transferFormat'.");

    if (_connectionState != ConnectionState.Disconnected) {
      return Future.error(GeneralError(
          "Cannot start a connection that is not in the 'Disconnected' state."));
    }

    _connectionState = ConnectionState.Connecting;

    _startInternalPromise = _startInternal(transferFormat);
    await _startInternalPromise;

    // The TypeScript compiler thinks that connectionState must be Connecting here. The TypeScript compiler is wrong.
    if (_connectionState == ConnectionState.Disconnecting) {
      // stop() was called and transitioned the client into the Disconnecting state.
      const message =
          "Failed to start the HttpConnection before stop() was called.";
      _logger?.severe(message);

      // We cannot await stopPromise inside startInternal since stopInternal awaits the startInternalPromise.
      await _stopPromise;

      return Future.error(GeneralError(message));
    } else if (_connectionState != ConnectionState.Connected) {
      // stop() was called and transitioned the client into the Disconnecting state.
      const message =
          "HttpConnection.startInternal completed gracefully but didn't enter the connection into the connected state!";
      _logger?.severe(message);
      return Future.error(GeneralError(message));
    }

    _connectionStarted = true;
  }

  @override
  Future<void> send(Object data) {
    if (_connectionState != ConnectionState.Connected) {
      return Future.error(GeneralError(
          "Cannot send data if the connection is not in the 'Connected' State."));
    }

    if (_sendQueue == null) {
      _sendQueue = new TransportSendQueue(_transport);
    }

    // Transport will not be null if state is connected
    return _sendQueue.send(data);
  }

  @override
  Future<void> stop({Exception error}) async {
    if (_connectionState == ConnectionState.Disconnected) {
      _logger?.finer(
          "Call to HttpConnection.stop($error) ignored because the connection is already in the disconnected state.");
      return Future.value();
    }

    if (_connectionState == ConnectionState.Disconnecting) {
      _logger?.finer(
          "Call to HttpConnection.stop($error) ignored because the connection is already in the disconnecting state.");
      return _stopPromise;
    }

    _connectionState = ConnectionState.Disconnecting;

    // Don't complete stop() until stopConnection() completes.
    _stopPromiseCompleter = Completer();
    _stopPromise = _stopPromiseCompleter.future;

    // stopInternal should never throw so just observe it.
    await _stopInternal(error: error);
    await _stopPromise;
  }

  Future<void> _stopInternal({Exception error}) async {
    // Set error as soon as possible otherwise there is a race between
    // the transport closing and providing an error and the error from a close message
    // We would prefer the close message error.
    _stopError = error;

    try {
      await _startInternalPromise;
    } catch (e) {
      // This exception is returned to the user as a rejected Promise from the start method.
    }

    // The transport's onclose will trigger stopConnection which will run our onclose event.
    // The transport should always be set if currently connected. If it wasn't set, it's likely because
    // stop was called during start() and start() failed.
    if (_transport != null) {
      try {
        await _transport.stop();
      } catch (e) {
        _logger?.severe("HttpConnection.transport.stop() threw error '$e'.");
        _stopConnection();
      }

      _transport = null;
    } else {
      _logger?.finer(
          "HttpConnection.transport is undefined in HttpConnection.stop() because start() failed.");
      _stopConnection();
    }
  }

  Future<void> _startInternal(TransferFormat transferFormat) async {
    // Store the original base url and the access token factory since they may change
    // as part of negotiating
    var url = baseUrl;
    _accessTokenFactory = _options.accessTokenFactory;

    try {
      if (_options.skipNegotiation) {
        if (_options.transport == HttpTransportType.WebSockets) {
          // No need to add a connection ID in this case
          _transport = _constructTransport(HttpTransportType.WebSockets);
          // We should just call connect directly in this case.
          // No fallback or negotiate in this case.
          await _startTransport(url, transferFormat);
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
          if (_connectionState == ConnectionState.Disconnecting ||
              _connectionState == ConnectionState.Disconnected) {
            throw GeneralError(
                "The connection was stopped during negotiation.");
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

      if (_connectionState == ConnectionState.Connecting) {
        // Ensure the connection transitions to the connected state prior to completing this.startInternalPromise.
        // start() will handle the case when stop was called and startInternal exits still in the disconnecting state.
        _logger?.finer("The HttpConnection connected successfully.");
        _connectionState = ConnectionState.Connected;
      }

      // stop() is waiting on us via this.startInternalPromise so keep this.transport around so it can clean up.
      // This is the only case startInternal can exit in neither the connected nor disconnected state because stopConnection()
      // will transition to the disconnected state. start() will wait for the transition using the stopPromise.
    } catch (e) {
      _logger?.severe("Failed to start the connection: ${e.toString()}");
      _connectionState = ConnectionState.Disconnected;
      _transport = null;
      return Future.error(e);
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
      final SignalRHttpRequest options = SignalRHttpRequest(
          content: "",
          headers: headers,
          timeout: maxRequestTimeoutMilliseconds);
      final response = await _httpClient.post(negotiateUrl, options: options);

      if (response.statusCode != 200) {
        return Future.error(GeneralError(
            "Unexpected status code returned from negotiate ${response.statusCode}"));
      }

      if (!(response.content is String)) {
        return Future.error(
            GeneralError("Negotation response content must be a json."));
      }

      var negotiateResponse =
          NegotiateResponse.fromJson(json.decode(response.content as String));
      if (negotiateResponse.negotiateVersion == null ||
          negotiateResponse.negotiateVersion < 1) {
        // Negotiate version 0 doesn't use connectionToken
        // So we set it equal to connectionId so all our logic can use connectionToken without being aware of the negotiate version
        negotiateResponse.connectionToken = negotiateResponse.connectionId;
      }
      return negotiateResponse;
    } catch (e) {
      _logger?.severe(
          "Failed to complete negotiation with the server: ${e.toString()}");
      return Future.error(e);
    }
  }

  String _createConnectUrl(String url, String connectionToken) {
    if (connectionToken != null) {
      return url;
    }

    return url + (url.indexOf("?") == -1 ? "?" : "&") + "id=$connectionToken";
  }

  Future<void> _createTransport(
      String url,
      Object requestedTransport,
      NegotiateResponse negotiateResponse,
      TransferFormat requestedTransferFormat) async {
    var connectUrl = _createConnectUrl(url, negotiateResponse.connectionToken);
    if (_isITransport(requestedTransport)) {
      _logger?.finer(
          "Connection was provided an instance of ITransport, using that directly.");
      _transport = requestedTransport;
      await _startTransport(connectUrl, requestedTransferFormat);

      connectionId = negotiateResponse.connectionId;
      return;
    }

    final List<Object> transportExceptions = [];
    final transports = negotiateResponse.availableTransports ?? [];
    NegotiateResponse negotiate = negotiateResponse;
    for (var endpoint in transports) {
      _connectionState = ConnectionState.Connecting;

      try {
        _transport = _resolveTransport(
            endpoint, requestedTransport, requestedTransferFormat);
      } catch (e) {
        transportExceptions.add("${endpoint.transport} failed: $e");
        continue;
      }

      if (negotiate == null) {
        try {
          negotiate = await _getNegotiationResponse(url);
        } catch (ex) {
          return Future.error(ex);
        }
        connectUrl = _createConnectUrl(url, negotiate.connectionToken);
      }

      try {
        await _startTransport(connectUrl, requestedTransferFormat);
        connectionId = negotiate.connectionId;
        return;
      } catch (ex) {
        _logger?.severe(
            "Failed to start the transport '${endpoint.transport}': ${ex.toString()}");
        negotiate = null;
        transportExceptions.add("${endpoint.transport} failed: $ex");

        if (_connectionState != ConnectionState.Connecting) {
          const message =
              "Failed to select transport before stop() was called.";
          _logger?.finer(message);
          return Future.error(GeneralError(message));
        }
      }
    }

    if (transportExceptions.length > 0) {
      return Future.error(GeneralError(
          "Unable to connect to the server with any of the available transports. ${transportExceptions.join(" ")}"));
    }
    return Future.error(GeneralError(
        "None of the transports supported by the client are supported by the server."));
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

  Future<void> _startTransport(String url, TransferFormat transferFormat) {
    _transport.onReceive = onreceive;
    _transport.onClose = _stopConnection;
    return _transport.connect(url, transferFormat);
  }

  ITransport _resolveTransport(
      AvailableTransport endpoint,
      HttpTransportType requestedTransport,
      TransferFormat requestedTransferFormat) {
    final transport = endpoint.transport;
    if (transport == null) {
      _logger?.finer(
          "Skipping transport '${endpoint.transport}' because it is not supported by this client.");
      throw GeneralError(
          "Skipping transport '${endpoint.transport}' because it is not supported by this client.");
    } else {
      if (transportMatches(requestedTransport, transport)) {
        final transferFormats = endpoint.transferFormats;
        if (transferFormats.indexOf(requestedTransferFormat) >= 0) {
          _logger?.finer("Selecting transport '${transport.toString()}'.");
          try {
            return _constructTransport(transport);
          } catch (ex) {
            return ex;
          }
        } else {
          _logger?.finer(
              "Skipping transport '$transport' because it does not support the requested transfer format '$requestedTransferFormat'.");
          throw GeneralError(
              "Skipping transport '$transport' because it does not support the requested transfer format '$requestedTransferFormat'.");
        }
      } else {
        _logger?.finer(
            "Skipping transport '$transport' because it was disabled by the client.");
        throw GeneralError(
            "Skipping transport '$transport' because it was disabled by the client.");
      }
    }
  }

  bool _isITransport(Object transport) {
    return transport is ITransport;
  }

  void _stopConnection({Exception error}) {
    _logger?.finer(
        "HttpConnection.stopConnection(${error ?? "Unknown"}) called while in state $_connectionState.");

    _transport = null;

    // If we have a stopError, it takes precedence over the error from the transport
    error = _stopError ?? error;
    _stopError = null;

    if (_connectionState == ConnectionState.Disconnected) {
      _logger?.finer(
          "Call to HttpConnection.stopConnection($error) was ignored because the connection is already in the disconnected state.");
      return;
    }

    if (_connectionState == ConnectionState.Connecting) {
      _logger?.warning(
          "Call to HttpConnection.stopConnection($error) was ignored because the connection hasn't yet left the in the connecting state.");
      throw GeneralError(
          "HttpConnection.stopConnection($error) was called while the connection is still in the connecting state.");
    }

    if (_connectionState == ConnectionState.Disconnecting) {
      // A call to stop() induced this call to stopConnection and needs to be completed.
      // Any stop() awaiters will be scheduled to continue after the onclose callback fires.
      _stopPromiseCompleter.complete();
    }

    if (error != null) {
      _logger?.severe("Connection disconnected with error '$error'.");
    } else {
      _logger?.info("Connection disconnected.");
    }

    if (_sendQueue != null) {
      _sendQueue.stop().catchError((e) {
        _logger?.severe("TransportSendQueue.stop() threw error '$e'.");
      });
      _sendQueue = null;
    }

    connectionId = null;
    _connectionState = ConnectionState.Disconnected;

    if (_connectionStarted) {
      _connectionStarted = false;

      try {
        if (onclose != null) {
          onclose(error: error);
        }
      } catch (e) {
        _logger?.severe("HttpConnection.onclose($error) threw error '$e'.");
      }
    }
  }

  String _resolveNegotiateUrl(String url) {
    final index = url.indexOf("?");
    var negotiateUrl = url.substring(0, index == -1 ? url.length : index);
    if (negotiateUrl[negotiateUrl.length - 1] != "/") {
      negotiateUrl += "/";
    }
    negotiateUrl += "negotiate";
    negotiateUrl += index == -1 ? "" : url.substring(index);

    if (negotiateUrl.indexOf("negotiateVersion") == -1) {
      negotiateUrl += index == -1 ? "?" : "&";
      negotiateUrl += "negotiateVersion=$_negotiateVersion";
    }
    return negotiateUrl;
  }

  static bool transportMatches(
      HttpTransportType requestedTransport, HttpTransportType actualTransport) {
    return (requestedTransport == null) ||
        (actualTransport == requestedTransport);
  }
}
