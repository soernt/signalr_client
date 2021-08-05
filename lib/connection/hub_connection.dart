import 'dart:async';

import 'package:logging/logging.dart';
import 'package:signalr_netcore/policies/default_reconnect_policy.dart';
import 'package:signalr_netcore/protocols/json_hub_protocol.dart';
import 'package:signalr_netcore/transport/itransport.dart';
import 'package:tuple/tuple.dart';

import '../exceptions/errors.dart';
import '../policies/iretry_policy.dart';
import '../protocols/handshake_protocol.dart';
import '../protocols/ihub_protocol.dart';
import '../utils/utils.dart';
import 'http_connection.dart';
import 'http_connection_options.dart';
import 'iconnection.dart';

const int DEFAULT_TIMEOUT_IN_MS = 30 * 1000;
const int DEFAULT_PING_INTERVAL_IN_MS = 15 * 1000;

/// Describes the current state of the {@link HubConnection} to the server.
enum HubConnectionState {
  /// The hub connection is disconnected.
  Disconnected,

  /// The hub connection is connecting.
  Connecting,

  /// The hub connection is connected.
  Connected,

  /// The hub connection is disconnecting.
  Disconnecting,

  /// The hub connection is reconnecting.
  Reconnecting,
}

typedef InvocationEventCallback = void Function(
    HubMessageBase? invocationEvent, Exception? error);
typedef MethodInvocationFunc = void Function(List<Object> arguments);
typedef ClosedCallback = void Function(Exception? error);
typedef ReconnectingCallback = void Function({Exception? error});
typedef ReconnectedCallback = void Function({String? connectionId});

/// Represents a connection to a SignalR Hub
class HubConnection {
  // Either a string (json) or Uint8List (binary);
  late Object _cachedPingMessage;
  final IConnection _connection;
  final Logger? _logger;
  final IRetryPolicy _reconnectPolicy;
  final IHubProtocol _protocol;
  final HandshakeProtocol _handshakeProtocol;

  final Map<String?, InvocationEventCallback> _callbacks = {};
  final Map<String, List<MethodInvocationFunc>> _methods = {};

  final List<ClosedCallback> _closedCallbacks = [];
  final List<ReconnectingCallback> _reconnectingCallbacks = [];
  final List<ReconnectedCallback> _reconnectedCallbacks = [];

  bool _receivedHandshakeResponse = false;

  int _invocationId = 0;

  Completer? _handshakeCompleter;
  Exception? _stopDuringStartError;

  HubConnectionState _connectionState = HubConnectionState.Disconnected;

  // connectionStarted is tracked independently from connectionState, so we can check if the
  // connection ever did successfully transition from connecting to connected before disconnecting.
  bool _connectionStarted = false;
  Future<void>? _startPromise;
  Future<void>? _stopPromise;

  // The type of these a) doesn't matter and b) varies when building in browser and node contexts
  // Since we're building the WebPack bundle directly from the TypeScript, this matters (previously
  // we built the bundle from the compiled JavaScript).
  Timer? _reconnectDelayTimer;
  Timer? _timeoutTimer;
  Timer? _pingServerTimer;

  /// The server timeout in milliseconds.
  ///
  /// If this timeout elapses without receiving any messages from the server, the connection will be terminated with an error.
  /// The default timeout value is 30,000 milliseconds (30 seconds).
  ///
  int serverTimeoutInMilliseconds;

  /// Default interval at which to ping the server.
  ///
  /// The default value is 15,000 milliseconds (15 seconds).
  /// Allows the server to detect hard disconnects (like when a client unplugs their computer).
  ///
  int keepAliveIntervalInMilliseconds;

  /// Indicates the state of the {@link HubConnection} to the server.
  HubConnectionState? get state => _connectionState;

  /// Represents the connection id of the {@link HubConnection} on the server. The connection id will be null when the connection is either
  /// in the disconnected state or if the negotiation step was skipped.
  String? get connectionId => _connection.connectionId;

  /// Indicates the url of the {@link HubConnection} to the server. */
  String? get baseUrl => _connection.baseUrl;

  /// Sets a new url for the HubConnection. Note that the url can only be changed when the connection is in either the Disconnected or
  /// Reconnecting states.
  /// @param {string} url The url to connect to.
  set baseUrl(String? url) {
    if (_connectionState != HubConnectionState.Disconnected &&
        _connectionState != HubConnectionState.Reconnecting) {
      throw GeneralError(
          "The HubConnection must be in the Disconnected or Reconnecting state to change the url.");
    }

    if (url == null) {
      throw GeneralError("The HubConnection url must be a valid url.");
    }

    _connection.baseUrl = url;
  }

  HubConnection(
      {required IConnection connection,
      required IHubProtocol protocol,
      Logger? logger,
      IRetryPolicy? reconnectPolicy,
      this.serverTimeoutInMilliseconds = DEFAULT_TIMEOUT_IN_MS,
      this.keepAliveIntervalInMilliseconds = DEFAULT_PING_INTERVAL_IN_MS})
      : this._connection = connection,
        this._protocol = protocol,
        this._reconnectPolicy = reconnectPolicy ?? DefaultRetryPolicy(),
        this._handshakeProtocol = HandshakeProtocol(),
        this._logger = logger {
    _connection.onReceive = _processIncomingData;
    _connection.onClose = _connectionClosed;
    _cachedPingMessage = _protocol.writeMessage(PingMessage());
  }

  factory HubConnection.create(
          IConnection connection, Logger? logger, IHubProtocol protocol,
          {IRetryPolicy? reconnectPolicy}) =>
      HubConnection(
          connection: connection,
          protocol: protocol,
          reconnectPolicy: reconnectPolicy);

  factory HubConnection.builder(
    String url, {
    HttpConnectionOptions options = const HttpConnectionOptions(),
    bool withAutomaticRetry = true,
    HttpTransportType? transportType,
    Logger? logger,
    IHubProtocol? protocol,
    IRetryPolicy? reconnectPolicy,
    List<int>? retryDelays,
  }) {
    final connection = HttpConnection(
      url,
      options: transportType == null
          ? options
          : options.copyWith(transport: transportType),
    );

    IRetryPolicy? reconnectPolicy;

    if (withAutomaticRetry) {
      if (reconnectPolicy == null && retryDelays == null) {
        reconnectPolicy = DefaultRetryPolicy();
      } else if (retryDelays != null) {
        reconnectPolicy = DefaultRetryPolicy(retryDelays: retryDelays);
      } else {
        reconnectPolicy = reconnectPolicy;
      }
    }

    return HubConnection.create(
        connection, logger, protocol ?? JsonHubProtocol(),
        reconnectPolicy: reconnectPolicy);
  }

  /// Starts the connection.
  ///
  /// Returns a Promise that resolves when the connection has been successfully established, or rejects with an error.
  ///
  Future<void>? start() async {
    _startPromise = _startWithStateTransitions();
    return _startPromise;
  }

  Future<void> _startWithStateTransitions() async {
    if (_connectionState != HubConnectionState.Disconnected) {
      return Future.error(GeneralError(
          "Cannot start a HubConnection that is not in the 'Disconnected' state."));
    }

    _connectionState = HubConnectionState.Connecting;
    _logger?.finer("Starting HubConnection.");

    try {
      await _startInternal();

      _connectionState = HubConnectionState.Connected;
      _connectionStarted = true;
      _logger?.finer("HubConnection connected successfully.");
    } catch (e) {
      _connectionState = HubConnectionState.Disconnected;
      _logger?.finer(
          "HubConnection failed to start successfully because of error '$e'.");
      return Future.error(e);
    }
  }

  _startInternal() async {
    _stopDuringStartError = null;
    _receivedHandshakeResponse = false;
    // Set up the promise before any connection is (re)started otherwise it could race with received messages
    _handshakeCompleter = Completer();
    await _connection.start(transferFormat: _protocol.transferFormat);

    try {
      final handshakeRequest =
          HandshakeRequestMessage(_protocol.name, _protocol.version);

      _logger?.finer("Sending handshake request.");

      await _sendMessage(
          _handshakeProtocol.writeHandshakeRequest(handshakeRequest));

      _logger?.info("Using HubProtocol '${_protocol.name}'.");

      // defensively cleanup timeout in case we receive a message from the server before we finish start
      _cleanupTimeout();
      _resetTimeoutPeriod();
      _resetKeepAliveInterval();

      await _handshakeCompleter!.future;

      // It's important to check the stopDuringStartError instead of just relying on the handshakePromise
      // being rejected on close, because this continuation can run after both the handshake completed successfully
      // and the connection was closed.
      if (_stopDuringStartError != null) {
        // It's important to throw instead of returning a rejected promise, because we don't want to allow any state
        // transitions to occur between now and the calling code observing the exceptions. Returning a rejected promise
        // will cause the calling continuation to get scheduled to run later.
        throw _stopDuringStartError!;
      }
    } on Exception catch (e) {
      _logger?.finer(
          "Hub handshake failed with error '$e' during start(). Stopping HubConnection.");

      _cleanupTimeout();
      _cleanupPingTimer();

      // HttpConnection.stop() should not complete until after the onclose callback is invoked.
      // This will transition the HubConnection to the disconnected state before HttpConnection.stop() completes.
      await _connection.stop(error: e);
      rethrow;
    }
  }

  /// Stops the connection.
  ///
  /// Returns a Promise that resolves when the connection has been successfully terminated, or rejects with an error.
  ///
  Future<void> stop() async {
    // Capture the start promise before the connection might be restarted in an onclose callback.
    final startPromise = _startPromise;

    _stopPromise = _stopInternal();
    await _stopPromise;

    try {
      // Awaiting undefined continues immediately
      await startPromise;
    } catch (e) {
      // This exception is returned to the user as a rejected Promise from the start method.
    }
  }

  Future<void>? _stopInternal({Exception? error}) async {
    if (_connectionState == HubConnectionState.Disconnected) {
      _logger?.finer(
          "Call to HubConnection.stop($error) ignored because it is already in the disconnected state.");
      return Future.value();
    }

    if (_connectionState == HubConnectionState.Disconnecting) {
      _logger?.finer(
          "Call to HttpConnection.stop($error) ignored because the connection is already in the disconnecting state.");
      return _stopPromise;
    }

    _connectionState = HubConnectionState.Disconnecting;

    _logger?.finer("Stopping HubConnection.");

    if (_reconnectDelayTimer != null) {
      // We're in a reconnect delay which means the underlying connection is currently already stopped.
      // Just clear the handle to stop the reconnect loop (which no one is waiting on thankfully) and
      // fire the onclose callbacks.
      _logger?.finer(
          "Connection stopped during reconnect delay. Done reconnecting.");

      _cleanupReconnectTimer();
      _completeClose();
      return Future.value();
    }

    _cleanupTimeout();
    _cleanupPingTimer();
    _stopDuringStartError = error ??
        GeneralError(
            "The connection was stopped before the hub handshake could complete.");

    // HttpConnection.stop() should not complete until after either HttpConnection.start() fails
    // or the onclose callback is invoked. The onclose callback will transition the HubConnection
    // to the disconnected state if need be before HttpConnection.stop() completes.
    return _connection.stop(error: error);
  }

  /// Invokes a streaming hub method on the server using the specified name and arguments.
  ///
  /// T: The type of the items returned by the server.
  /// methodName: The name of the server method to invoke.
  /// args: The arguments used to invoke the server method.
  /// Returns an object that yields results from the server as they are received.
  ///
  Stream<Object?> stream(String methodName, List<Object> args) {
    final t = _replaceStreamingParams(args);
    final invocationDescriptor =
        _createStreamInvocation(methodName, args, t.item2);

    late Future<void> promiseQueue;
    final StreamController streamController = StreamController<Object?>(
      onCancel: () {
        final cancelInvocation =
            _createCancelInvocation(invocationDescriptor.invocationId);
        _callbacks.remove(invocationDescriptor.invocationId);

        return promiseQueue.then((_) => _sendWithProtocol(cancelInvocation));
      },
    );

    _callbacks[invocationDescriptor.invocationId] =
        (HubMessageBase? invocationEvent, Exception? error) {
      if (error != null) {
        streamController.addError(error);
        return;
      } else if (invocationEvent != null) {
        // invocationEvent will not be null when an error is not passed to the callback
        if (invocationEvent is CompletionMessage) {
          if (invocationEvent.error != null) {
            streamController.addError(GeneralError(invocationEvent.error));
          } else {
            streamController.close();
          }
        } else if (invocationEvent is StreamItemMessage) {
          streamController.add(invocationEvent.item);
        }
      }
    };

    promiseQueue = _sendWithProtocol(invocationDescriptor).catchError((e) {
      streamController.addError(e);
      _callbacks.remove(invocationDescriptor.invocationId);
    });

    _launchStreams(t.item1, promiseQueue);

    return streamController.stream;
  }

  Future<void> _sendMessage(Object message) {
    _resetKeepAliveInterval();
    return _connection.send(message);
  }

  /// Sends a js object to the server.
  /// message: The object to serialize and send.
  ///
  Future<void> _sendWithProtocol(Object message) {
    return _sendMessage(_protocol.writeMessage(message as HubMessageBase));
  }

  /// Invokes a hub method on the server using the specified name and arguments. Does not wait for a response from the receiver.
  ///
  /// The Promise returned by this method resolves when the client has sent the invocation to the server. The server may still
  /// be processing the invocation.
  ///
  /// methodName: The name of the server method to invoke.
  /// args: The arguments used to invoke the server method.
  /// Returns a Promise that resolves when the invocation has been successfully sent, or rejects with an error.
  ///
  Future<void> send(String methodName, {List<Object> args = const []}) {
    final t = _replaceStreamingParams(args);
    final sendPromise =
        _sendWithProtocol(_createInvocation(methodName, args, true, t.item2));

    _launchStreams(t.item1, sendPromise);
    return sendPromise;
  }

  /// Invokes a hub method on the server using the specified name and arguments.
  ///
  /// The Future returned by this method resolves when the server indicates it has finished invoking the method. When the Future
  /// resolves, the server has finished invoking the method. If the server method returns a result, it is produced as the result of
  /// resolving the Promise.
  ///
  /// methodName: The name of the server method to invoke.
  /// args: The arguments used to invoke the server method.
  /// Returns a Future that resolves with the result of the server method (if any), or rejects with an error.
  ///
  Future<Object> invoke(String methodName, {List<Object> args = const []}) {
    final t = _replaceStreamingParams(args);
    final invocationDescriptor =
        _createInvocation(methodName, args, false, t.item2);

    final completer = Completer<Object>();

    _callbacks[invocationDescriptor.invocationId] =
        (HubMessageBase? invocationEvent, Exception? error) {
      if (error != null) {
        if (!completer.isCompleted) completer.completeError(error);
        return;
      } else if (invocationEvent != null) {
        if (invocationEvent is CompletionMessage) {
          if (invocationEvent.error != null) {
            if (!completer.isCompleted) {
              completer.completeError(new GeneralError(invocationEvent.error));
            }
          } else {
            if (!completer.isCompleted) {
              completer.complete(invocationEvent.result);
            }
          }
        } else {
          if (!completer.isCompleted) {
            completer.completeError(new GeneralError(
                "Unexpected message type: ${invocationEvent.type}"));
          }
        }
      }
    };

    final promiseQueue =
        _sendWithProtocol(invocationDescriptor).catchError((e) {
      if (!completer.isCompleted) completer.completeError(e);
      // invocationId will always have a value for a non-blocking invocation
      _callbacks.remove(invocationDescriptor.invocationId);
    });

    _launchStreams(t.item1, promiseQueue);

    return completer.future;
  }

  ///  Registers a handler that will be invoked when the hub method with the specified method name is invoked.
  ///
  /// methodName: The name of the hub method to define.
  /// newMethod: The handler that will be raised when the hub method is invoked.
  ///
  void on(String methodName, MethodInvocationFunc newMethod) {
    if (methodName.isEmpty) {
      print("[HubConnection][on] Cannot listen to on an empty method");
      return;
    }

    methodName = methodName.toLowerCase();
    if (_methods[methodName] == null) {
      _methods[methodName] = [];
    }

    // Preventing adding the same handler multiple times.
    if (_methods[methodName]!.indexOf(newMethod) != -1) {
      return;
    }

    _methods[methodName]!.add(newMethod);
  }

  /// Removes the specified handler for the specified hub method.
  ///
  /// You must pass the exact same Function instance as was previously passed to HubConnection.on. Passing a different instance (even if the function
  /// body is the same) will not remove the handler.
  ///
  /// methodName: The name of the method to remove handlers for.
  /// method: The handler to remove. This must be the same Function instance as the one passed to {@link @microsoft/signalr.HubConnection.on}.
  /// If the method handler is omitted, all handlers for that method will be removed.
  ///
  void off(String methodName, {MethodInvocationFunc? method}) {
    if (methodName.isEmpty) {
      print("[HubConnection][off] Cannot listen off an empty method");
      return;
    }

    methodName = methodName.toLowerCase();
    final List<void Function(List<Object>)>? handlers = _methods[methodName];
    if (handlers == null) {
      return;
    }

    if (method != null) {
      final removeIdx = handlers.indexOf(method);
      if (removeIdx != -1) {
        handlers.removeAt(removeIdx);
        if (handlers.length == 0) {
          _methods.remove(methodName);
        }
      }
    } else {
      _methods.remove(methodName);
    }
  }

  /// Registers a handler that will be invoked when the connection is closed.
  ///
  /// callback: The handler that will be invoked when the connection is closed. Optionally receives a single argument containing the error that caused the connection to close (if any).
  ///
  void onclose(ClosedCallback callback) {
    if (callback != null) {
      _closedCallbacks.add(callback);
    }
  }

  /// Registers a handler that will be invoked when the connection starts reconnecting.
  ///
  /// callback: The handler that will be invoked when the connection starts reconnecting. Optionally receives a single argument containing the error that caused the connection to start reconnecting (if any).
  ///
  onreconnecting(ReconnectingCallback callback) {
    if (callback != null) {
      _reconnectingCallbacks.add(callback);
    }
  }

  /// Registers a handler that will be invoked when the connection successfully reconnects.
  ///
  /// callback: The handler that will be invoked when the connection successfully reconnects.
  ///
  onreconnected(ReconnectedCallback callback) {
    if (callback != null) {
      _reconnectedCallbacks.add(callback);
    }
  }

  void _processIncomingData(Object? data) {
    _cleanupTimeout();

    if (!_receivedHandshakeResponse) {
      data = _processHandshakeResponse(data);
      _receivedHandshakeResponse = true;
    }

    // Data may have all been read when processing handshake response
    if (data != null) {
      // Parse the messages
      final messages = _protocol.parseMessages(data, _logger);

      for (final message in messages) {
        _logger?.finest("Handle message of type '${message.type}'.");
        switch (message.type) {
          case MessageType.Invocation:
            _invokeClientMethod(message as InvocationMessage);
            break;
          case MessageType.StreamItem:
          case MessageType.Completion:
            final invocationMsg = message as HubInvocationMessage;
            final void Function(HubMessageBase, Exception?)? callback =
                _callbacks[invocationMsg.invocationId];
            if (callback != null) {
              if (message.type == MessageType.Completion) {
                _callbacks.remove(invocationMsg.invocationId);
              }
              callback(message, null);
            }
            break;
          case MessageType.Ping:
            // Don't care about pings
            break;
          case MessageType.Close:
            _logger?.info("Close message received from server.");
            final closeMessage = message as CloseMessage;

            final Exception? error = closeMessage.error != null
                ? GeneralError(
                    "Server returned an error on close: " + closeMessage.error!)
                : null;

            if (closeMessage.allowReconnect == true) {
              // It feels wrong not to await connection.stop() here, but processIncomingData is called as part of an onreceive callback which is not async,
              // this is already the behavior for serverTimeout(), and HttpConnection.Stop() should catch and log all possible exceptions.

              _connection.stop(error: error);
            } else {
              // We cannot await stopInternal() here, but subsequent calls to stop() will await this if stopInternal() is still ongoing.
              _stopPromise = _stopInternal(error: error);
            }

            break;
          default:
            _logger?.warning("Invalid message type: '${message.type}'");
            break;
        }
      }
    }

    _resetTimeoutPeriod();
  }

  /// data is either a string (json) or a Uint8List (binary)
  Object? _processHandshakeResponse(Object? data) {
    ParseHandshakeResponseResult handshakeResult;

    try {
      handshakeResult = _handshakeProtocol.parseHandshakeResponse(data);
    } catch (e) {
      final message = "Error parsing handshake response: '${e.toString()}'.";
      _logger?.severe(message);

      final error = GeneralError(message);

      if (!_handshakeCompleter!.isCompleted) {
        _handshakeCompleter?.completeError(error);
      }
      _handshakeCompleter = null;
      throw error;
    }
    if (handshakeResult.handshakeResponseMessage.error.isNotNullOrEmpty) {
      final message =
          "Server returned handshake error: '${handshakeResult.handshakeResponseMessage.error}'";
      _logger?.severe(message);

      final error = GeneralError(message);

      if (!_handshakeCompleter!.isCompleted) {
        _handshakeCompleter?.completeError(error);
      }
      _handshakeCompleter = null;
      throw error;
    } else {
      _logger?.finer("Server handshake complete.");
    }

    if (!_handshakeCompleter!.isCompleted) _handshakeCompleter?.complete();
    _handshakeCompleter = null;
    return handshakeResult.remainingData;
  }

  void _resetKeepAliveInterval() {
    _cleanupPingTimer();
    _pingServerTimer =
        Timer.periodic(Duration(milliseconds: keepAliveIntervalInMilliseconds),
            (Timer t) async {
      if (_connectionState == HubConnectionState.Connected) {
        try {
          await _sendMessage(_cachedPingMessage);
        } catch (e) {
          // We don't care about the error. It should be seen elsewhere in the client.
          // The connection is probably in a bad or closed state now, cleanup the timer so it stops triggering
          _cleanupPingTimer();
        }
      }
    });
  }

  void _resetTimeoutPeriod() {
    _cleanupTimeout();
    if ((_connection.features == null) ||
        (_connection.features!.inherentKeepAlive == null) ||
        (!_connection.features!.inherentKeepAlive!)) {
      // Set the timeout timer
      _timeoutTimer = Timer.periodic(
          Duration(milliseconds: serverTimeoutInMilliseconds), _serverTimeout);
    }
  }

  void _serverTimeout(Timer t) {
    // The server hasn't talked to us in a while. It doesn't like us anymore ... :(
    // Terminate the connection, but we don't need to wait on the promise.
    _connection.stop(
        error: GeneralError(
            "Server timeout elapsed without receiving a message from the server."));
  }

  void _invokeClientMethod(InvocationMessage invocationMessage) {
    final methods = _methods[invocationMessage.target!.toLowerCase()];
    if (methods != null) {
      methods.forEach((m) => m(invocationMessage.arguments));
      if (invocationMessage.invocationId.isNotNullOrEmpty) {
        // This is not supported in v1. So we return an error to avoid blocking the server waiting for the response.
        final message =
            "Server requested a response, which is not supported in this version of the client.";
        _logger?.severe(message);

        // We don't need to wait on this Promise.
        _stopPromise = _stopInternal(error: GeneralError(message));
      }
    } else {
      _logger?.warning(
          "No client method with the name '${invocationMessage.target}' found.");
    }
  }

  void _connectionClosed({Exception? error}) {
    _logger?.finer(
        "HubConnection.connectionClosed($error) called while in state $_connectionState.");

    // Triggering this.handshakeRejecter is insufficient because it could already be resolved without the continuation having run yet.
    _stopDuringStartError = _stopDuringStartError ??
        error ??
        GeneralError(
            "The underlying connection was closed before the hub handshake could complete.");

    // If the handshake is in progress, start will be waiting for the handshake promise, so we complete it.
    // If it has already completed, this should just noop.
    if (_handshakeCompleter != null) {
      if (!_handshakeCompleter!.isCompleted) _handshakeCompleter!.complete();
    }

    _cancelCallbacksWithError(error ??
        GeneralError(
            "Invocation canceled due to the underlying connection being closed."));

    _cleanupTimeout();
    _cleanupPingTimer();

    if (_connectionState == HubConnectionState.Disconnecting) {
      _completeClose(error: error);
    } else if (_connectionState == HubConnectionState.Connected &&
        _reconnectPolicy != null) {
      _reconnect(error: error);
    } else if (_connectionState == HubConnectionState.Connected) {
      _completeClose(error: error);
    }

    // If none of the above if conditions were true were called the HubConnection must be in either:
    // 1. The Connecting state in which case the handshakeResolver will complete it and stopDuringStartError will fail it.
    // 2. The Reconnecting state in which case the handshakeResolver will complete it and stopDuringStartError will fail the current reconnect attempt
    //    and potentially continue the reconnect() loop.
    // 3. The Disconnected state in which case we're already done.
  }

  _completeClose({Exception? error}) {
    if (_connectionStarted) {
      _connectionState = HubConnectionState.Disconnected;
      _connectionStarted = false;

      try {
        _closedCallbacks.forEach((c) => c(error)); // removed "this"
      } catch (e) {
        _logger?.severe(
            "An onclose callback called with error '$error' threw error '$e'.");
      }
    }
  }

  _reconnect({Exception? error}) async {
    final reconnectStartTime = DateTime.now();
    var previousReconnectAttempts = 0;
    Exception retryError = error != null
        ? error
        : GeneralError("Attempting to reconnect due to a unknown error.");

    var nextRetryDelay =
        _getNextRetryDelay(previousReconnectAttempts++, 0, retryError);

    if (nextRetryDelay == null) {
      _logger?.finer(
          "Connection not reconnecting because the IRetryPolicy returned null on the first reconnect attempt.");
      _completeClose(error: error);
      return;
    }

    _connectionState = HubConnectionState.Reconnecting;

    if (error != null) {
      _logger?.info("Connection reconnecting because of error '$error'.");
    } else {
      _logger?.info("Connection reconnecting.");
    }

    try {
      _reconnectingCallbacks.forEach((c) => c(error: error));
    } catch (e) {
      _logger?.severe(
          "An onreconnecting callback called with error '$error' threw error '$e'.");
    }

    // Exit early if an onreconnecting callback called connection.stop().
    if (_connectionState != HubConnectionState.Reconnecting) {
      _logger?.finer(
          "Connection left the reconnecting state in onreconnecting callback. Done reconnecting.");
      return;
    }

    while (nextRetryDelay != null) {
      _logger?.info(
          "Reconnect attempt number $previousReconnectAttempts will start in $nextRetryDelay ms.");

      await Future.delayed(Duration(milliseconds: nextRetryDelay));

      if (_connectionState != HubConnectionState.Reconnecting) {
        _logger?.finer(
            "Connection left the reconnecting state during reconnect delay. Done reconnecting.");
        return;
      }

      try {
        await _startInternal();

        _connectionState = HubConnectionState.Connected;
        _logger?.info("HubConnection reconnected successfully.");

        try {
          _reconnectedCallbacks
              .forEach((c) => c(connectionId: _connection.connectionId));
        } catch (e) {
          _logger?.severe(
              "An onreconnected callback called with connectionId '${_connection.connectionId}; threw error '$e'.");
        }

        return;
      } on Exception catch (e) {
        _logger?.info("Reconnect attempt failed because of error '$e'.");

        if (_connectionState != HubConnectionState.Reconnecting) {
          _logger?.finer(
              "Connection left the reconnecting state during reconnect attempt. Done reconnecting.");
          return;
        }

        retryError = e;
        nextRetryDelay = _getNextRetryDelay(
            previousReconnectAttempts++,
            DateTime.now().difference(reconnectStartTime).inMilliseconds,
            retryError);
      }
    }

    _logger?.info(
        "Reconnect retries have been exhausted after ${DateTime.now().difference(reconnectStartTime).inMilliseconds} ms and $previousReconnectAttempts failed attempts. Connection disconnecting.");

    _completeClose();
  }

  int? _getNextRetryDelay(
      int previousRetryCount, int elapsedMilliseconds, Exception retryReason) {
    try {
      return _reconnectPolicy.nextRetryDelayInMilliseconds(
          RetryContext(elapsedMilliseconds, previousRetryCount, retryReason));
    } catch (e) {
      _logger?.severe(
          "IRetryPolicy.nextRetryDelayInMilliseconds($previousRetryCount, $elapsedMilliseconds) threw error '$e'.");
      return null;
    }
  }

  _cancelCallbacksWithError(Exception error) {
    final Map<String?, void Function(HubMessageBase?, Exception)> callbacks =
        _callbacks;
    _callbacks.clear();

    callbacks.forEach((_, value) => {value(null, error)});
  }

  void _cleanupPingTimer() {
    if (_pingServerTimer != null) {
      _pingServerTimer!.cancel();
      _pingServerTimer = null;
    }
  }

  void _cleanupTimeout() {
    if (_timeoutTimer != null) {
      _timeoutTimer!.cancel();
      _timeoutTimer = null;
    }
  }

  void _cleanupReconnectTimer() {
    if (_reconnectDelayTimer != null) {
      _reconnectDelayTimer!.cancel();
      _reconnectDelayTimer = null;
    }
  }

  InvocationMessage _createInvocation(String methodName, List<Object> args,
      bool nonblocking, List<String> streamIds) {
    if (nonblocking) {
      return InvocationMessage(
          target: methodName,
          arguments: args,
          streamIds: streamIds,
          headers: MessageHeaders());
    } else {
      final invocationId = _invocationId;
      _invocationId++;

      return InvocationMessage(
        target: methodName,
        arguments: args,
        streamIds: streamIds,
        headers: MessageHeaders(),
        invocationId: invocationId.toString(),
      );
    }
  }

  _launchStreams(List<Stream<Object>> streams, Future<void> promiseQueue) {
    if (streams.length == 0) {
      return;
    }

    // Synchronize stream data so they arrive in-order on the server
    if (promiseQueue == null) {
      promiseQueue = Future.value();
    }

    // We want to iterate over the keys, since the keys are the stream ids
    for (var i = 0; i < streams.length; i++) {
      streams[i].listen((item) {
        promiseQueue = promiseQueue.then((_) =>
            _sendWithProtocol(_createStreamItemMessage(i.toString(), item)));
      }, onDone: () {
        promiseQueue = promiseQueue.then(
            (_) => _sendWithProtocol(_createCompletionMessage(i.toString())));
      }, onError: (err) {
        String message;
        if (err is Exception) {
          message = err.toString();
        } else {
          message = "Unknown error";
        }

        promiseQueue = promiseQueue.then((_) => _sendWithProtocol(
            _createCompletionMessage(i.toString(), error: message)));
      });
    }
  }

  Tuple2<List<Stream<Object>>, List<String>> _replaceStreamingParams(
      List<Object> args) {
    final List<Stream<Object>> streams = [];
    final List<String> streamIds = [];

    for (var i = 0; i < args.length; i++) {
      final argument = args[i];
      if (argument is Stream) {
        final streamId = _invocationId;
        _invocationId++;
        // Store the stream for later use
        streams[streamId] = argument as Stream<Object>;
        streamIds.add(streamId.toString());

        // remove stream from args
        args.removeAt(i);
      }
    }

    return Tuple2<List<Stream<Object>>, List<String>>(streams, streamIds);
  }

  /// isObservable

  StreamInvocationMessage _createStreamInvocation(
      String methodName, List<Object> args, List<String> streamIds) {
    final invocationId = _invocationId;
    _invocationId++;

    return StreamInvocationMessage(
        methodName, args, streamIds, MessageHeaders(), invocationId.toString());
  }

  CancelInvocationMessage _createCancelInvocation(String? id) {
    return CancelInvocationMessage(new MessageHeaders(), id);
  }

  StreamItemMessage _createStreamItemMessage(String id, Object item) {
    return StreamItemMessage(item, new MessageHeaders(), id);
  }

  CompletionMessage _createCompletionMessage(String id,
      {Object? error, Object? result}) {
    if (error != null) {
      return CompletionMessage(
          error as String?, null, new MessageHeaders(), id);
    }

    return CompletionMessage(null, result, new MessageHeaders(), id);
  }
}
