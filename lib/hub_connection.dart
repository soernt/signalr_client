import 'dart:async';

import 'package:logging/logging.dart';

import 'errors.dart';
import 'handshake_protocol.dart';
import 'iconnection.dart';
import 'ihub_protocol.dart';
import 'utils.dart';

const int DEFAULT_TIMEOUT_IN_MS = 30 * 1000;
const int DEFAULT_PING_INTERVAL_IN_MS = 15 * 1000;

/// Describes the current state of the {@link HubConnection} to the server.
enum HubConnectionState {
  /// The hub connection is disconnected.
  Disconnected,

  /// The hub connection is connected.
  Connected,
}

typedef InvocationEventCallback = void Function(
    HubMessageBase? invocationEvent, Exception? error);
typedef MethodInvacationFunc = void Function(List<Object>? arguments);
typedef ClosedCallback = void Function(Exception? error);

/// Represents a connection to a SignalR Hub
class HubConnection {
  // Either a string (json) or Uint8List (binary);
  Object? _cachedPingMessage;
  final IConnection _connection;
  final Logger? _logger;
  final IHubProtocol _protocol;
  final HandshakeProtocol _handshakeProtocol;

  late Map<String?, InvocationEventCallback> _callbacks;
  late Map<String, List<MethodInvacationFunc>> _methods;
  late List<ClosedCallback> _closedCallbacks;

  int? _id;
  late bool _receivedHandshakeResponse;
  Completer? _handshakeCompleter;

  HubConnectionState? _connectionState;

  Timer? _timeoutTimer;
  Timer? _pingServerTimer;

  /// The server timeout in milliseconds.
  ///
  /// If this timeout elapses without receiving any messages from the server, the connection will be terminated with an error.
  /// The default timeout value is 30,000 milliseconds (30 seconds).
  ///
  late int serverTimeoutInMilliseconds;

  /// Default interval at which to ping the server.
  ///
  /// The default value is 15,000 milliseconds (15 seconds).
  /// Allows the server to detect hard disconnects (like when a client unplugs their computer).
  ///
  late int keepAliveIntervalInMilliseconds;

  /// Indicates the state of the {@link HubConnection} to the server.
  HubConnectionState? get state => this._connectionState;

  HubConnection(IConnection connection, Logger? logger, IHubProtocol protocol)
      : assert(connection != null),
        assert(protocol != null),
        _connection = connection,
        _logger = logger,
        _protocol = protocol,
        _handshakeProtocol = HandshakeProtocol() {
    serverTimeoutInMilliseconds = DEFAULT_TIMEOUT_IN_MS;
    keepAliveIntervalInMilliseconds = DEFAULT_PING_INTERVAL_IN_MS;

    _connection.onreceive = _processIncomingData;
    _connection.onclose = _connectionClosed;

    _callbacks = {};
    _methods = {};
    _closedCallbacks = [];
    _id = 0;
    _receivedHandshakeResponse = false;
    _connectionState = HubConnectionState.Disconnected;

    _cachedPingMessage = _protocol.writeMessage(PingMessage());
  }

  /// Starts the connection.
  ///
  /// Returns a Promise that resolves when the connection has been successfully established, or rejects with an error.
  ///
  Future<void> start() async {
    final handshakeRequest =
        HandshakeRequestMessage(this._protocol.name, this._protocol.version);

    _logger?.finer("Starting HubConnection.");

    _receivedHandshakeResponse = false;
    // Set up the Future before any connection is started otherwise it could race with received messages
    _handshakeCompleter = Completer();
    await _connection.start(transferFormat: _protocol.transferFormat);

    _logger?.finer("Sending handshake request.");
    await _sendMessage(
        _handshakeProtocol.writeHandshakeRequest(handshakeRequest));

    _logger?.info("Using HubProtocol '${_protocol.name}'.");

    // defensively cleanup timeout in case we receive a message from the server before we finish start
    _cleanupTimeoutTimer();
    _resetTimeoutPeriod();
    _resetKeepAliveInterval();

    // Wait for the handshake to complete before marking connection as connected
    await _handshakeCompleter!.future;
    _connectionState = HubConnectionState.Connected;
  }

  /// Stops the connection.
  ///
  /// Returns a Promise that resolves when the connection has been successfully terminated, or rejects with an error.
  ///
  Future<void> stop() {
    _logger?.finer("Stopping HubConnection.");

    _cleanupTimeoutTimer();
    _cleanupServerPingTimer();
    return _connection.stop(Exception("closed"));
  }

  /// Invokes a streaming hub method on the server using the specified name and arguments.
  ///
  /// T: The type of the items returned by the server.
  /// methodName: The name of the server method to invoke.
  /// args: The arguments used to invoke the server method.
  /// Returns an object that yields results from the server as they are received.
  ///
  Stream<Object?> stream(String methodName, List<Object> args) {
    final invocationMessage = _createStreamInvocation(methodName, args);

    var pauseSendingItems = false;
    final StreamController streamController = StreamController<Object?>(
      onCancel: () {
        final cancelMessage =
            _createCancelInvocation(invocationMessage.invocationId);
        final formatedCancelMessage = _protocol.writeMessage(cancelMessage);
        _callbacks.remove(invocationMessage.invocationId);
        _sendMessage(formatedCancelMessage);
      },
      onPause: () => pauseSendingItems = true,
      onResume: () => pauseSendingItems = false,
    );

    _callbacks[invocationMessage.invocationId] =
        (HubMessageBase? invocationEvent, Exception? error) {
      if (error != null) {
        streamController.addError(error);
        return;
      } else if (invocationEvent != null) {
        if (invocationEvent is CompletionMessage) {
          if (invocationEvent.error != null) {
            streamController.addError(new GeneralError(invocationEvent.error));
          } else {
            streamController.close();
          }
        } else if (invocationEvent is StreamItemMessage) {
          if (!pauseSendingItems) {
            streamController.add(invocationEvent.item);
          }
        }
      }
    };

    final formatedMessage = _protocol.writeMessage(invocationMessage);
    _sendMessage(formatedMessage).catchError((dynamic error) {
      streamController.addError(error as Error);
      _callbacks.remove(invocationMessage.invocationId);
    });

    return streamController.stream;
  }

  Future<void> _sendMessage(Object? message) {
    _resetKeepAliveInterval();
    _logger?.finest("Sending message.");
    return _connection.send(message);
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
  Future<void> send(String methodName, List<Object> args) {
    final invocationDescriptor = _createInvocation(methodName, args, true);
    final message = _protocol.writeMessage(invocationDescriptor);
    return _sendMessage(message);
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

  Future<Object> invoke(String methodName, {List<Object>? args}) {
    args = args ?? <Object>[];
    final invocationMessage = _createInvocation(methodName, args, false);

    final completer = Completer<Object>();

    _callbacks[invocationMessage.invocationId] =
        (HubMessageBase? invocationEvent, Exception? error) {
      if (error != null) {
        completer.completeError(error);
        return;
      } else if (invocationEvent != null) {
        if (invocationEvent is CompletionMessage) {
          if (invocationEvent.error != null) {
            completer.completeError(new GeneralError(invocationEvent.error));
          } else {
            completer.complete(invocationEvent.result);
          }
        } else {
          completer.completeError(new GeneralError(
              "Unexpected message type: ${invocationEvent.type}"));
        }
      }
    };

    final formatedMessage = _protocol.writeMessage(invocationMessage);
    _sendMessage(formatedMessage).catchError((dynamic error) {
      completer.completeError(error as Error);
      _callbacks.remove(invocationMessage.invocationId);
    });

    return completer.future;
  }

  ///  Registers a handler that will be invoked when the hub method with the specified method name is invoked.
  ///
  /// methodName: The name of the hub method to define.
  /// newMethod: The handler that will be raised when the hub method is invoked.
  ///
  void on(String methodName, MethodInvacationFunc newMethod) {
    if (isStringEmpty(methodName) || newMethod == null) {
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
  /// method: The handler to remove. This must be the same Function instance as the one passed to {@link @aspnet/signalr.HubConnection.on}.
  /// If the method handler is omitted, all handlers for that method will be removed.
  ///
  void off(String methodName, {MethodInvacationFunc? method}) {
    if (isStringEmpty(methodName)) {
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

  void _processIncomingData(Object? data) {
    _cleanupTimeoutTimer();

    _logger?.finest("Incomming message");

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
            final closeMsg = message as CloseMessage;

            // We don't want to wait on the stop itself.
            _connection.stop(!isStringEmpty(closeMsg.error)
                ? new GeneralError(
                    "Server returned an error on close: '${closeMsg.error}'")
                : null);

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

      // We don't want to wait on the stop itself.
      _connection.stop(error);
      _handshakeCompleter?.completeError(error);
      _handshakeCompleter = null;
      throw error;
    }
    if (!isStringEmpty(handshakeResult.handshakeResponseMessage.error)) {
      final message =
          "Server returned handshake error: '${handshakeResult.handshakeResponseMessage.error}'";
      _logger?.severe(message);

      _handshakeCompleter?.completeError(new GeneralError(message));
      _handshakeCompleter = null;
      // We don't want to wait on the stop itself.
      _connection.stop(GeneralError(message));
      throw GeneralError(message);
    } else {
      _logger?.finer("Server handshake complete.");
    }

    _handshakeCompleter?.complete();
    _handshakeCompleter = null;
    return handshakeResult.remainingData;
  }

  void _resetKeepAliveInterval() {
    _cleanupServerPingTimer();
    _pingServerTimer =
        Timer.periodic(Duration(milliseconds: keepAliveIntervalInMilliseconds),
            (Timer t) async {
      if (_connectionState == HubConnectionState.Connected) {
        try {
          await _sendMessage(_cachedPingMessage);
        } catch (e) {
          // We don't care about the error. It should be seen elsewhere in the client.
          // The connection is probably in a bad or closed state now, cleanup the timer so it stops triggering
          _cleanupServerPingTimer();
        }
      }
    });
  }

  void _resetTimeoutPeriod() {
    _cleanupTimeoutTimer();
    if ((_connection.features == null) ||
        (_connection.features!.inherentKeepAlive == null) ||
        (!_connection.features!.inherentKeepAlive!)) {
      // Set the timeout timer
      _timeoutTimer = Timer.periodic(
          Duration(milliseconds: serverTimeoutInMilliseconds), _serverTimeout);
    }
  }

  void _cleanupServerPingTimer() {
    _pingServerTimer?.cancel();
    _pingServerTimer = null;
  }

  void _cleanupTimeoutTimer() {
    this._timeoutTimer?.cancel();
    this._timeoutTimer = null;
  }

  void _serverTimeout(Timer t) {
    // The server hasn't talked to us in a while. It doesn't like us anymore ... :(
    // Terminate the connection, but we don't need to wait on the promise.
    _connection.stop(GeneralError(
        "Server timeout elapsed without receiving a message from the server."));
  }

  void _invokeClientMethod(InvocationMessage invocationMessage) {
    final methods = _methods[invocationMessage.target!.toLowerCase()];
    if (methods != null) {
      methods.forEach((m) => m(invocationMessage.arguments));
      if (!isStringEmpty(invocationMessage.invocationId)) {
        // This is not supported in v1. So we return an error to avoid blocking the server waiting for the response.
        final message =
            "Server requested a response, which is not supported in this version of the client.";
        _logger?.severe(message);

        // We don't need to wait on this Promise.
        _connection.stop(new GeneralError(message));
      }
    } else {
      _logger?.warning(
          "No client method with the name '${invocationMessage.target}' found.");
    }
  }

  void _connectionClosed(Exception? error) {
    final Map<String?, void Function(HubMessageBase?, Exception)> callbacks =
        _callbacks;
    callbacks.clear();

    _connectionState = HubConnectionState.Disconnected;

    // if handshake is in progress start will be waiting for the handshake promise, so we complete it
    // if it has already completed this should just noop
    _handshakeCompleter?.completeError(error!);

    final callbackError = error ??
        new GeneralError("Invocation canceled due to connection being closed.");
    callbacks.values.forEach((callback) => callback(null, callbackError));

    _cleanupTimeoutTimer();
    _cleanupServerPingTimer();

    _closedCallbacks.forEach((callback) => callback(error));
  }

  InvocationMessage _createInvocation(
      String methodName, List<Object> args, bool nonblocking) {
    if (nonblocking) {
      return InvocationMessage(methodName, args, MessageHeaders(), null);
    } else {
      final id = _id;
      _id = _id! + 1;
      return InvocationMessage(
          methodName, args, MessageHeaders(), id.toString());
    }
  }

  StreamInvocationMessage _createStreamInvocation(
      String methodName, List<Object> args) {
    final id = _id;
    _id = _id! + 1;
    return StreamInvocationMessage(
        methodName, args, MessageHeaders(), id.toString());
  }

  static CancelInvocationMessage _createCancelInvocation(String? id) {
    return CancelInvocationMessage(new MessageHeaders(), id);
  }
}
