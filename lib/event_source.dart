import 'dart:async' show Future, Stream, StreamController, Timer;
import 'dart:convert' show LineSplitter, utf8;
import 'dart:io' show HttpClient, HttpStatus;
import 'dart:math' show Random;

class MessageEvent {
  final String? name;
  final String? data;

  MessageEvent({this.name, this.data});
}

typedef HttpClientFactory = HttpClient Function();

/// A client for server-sent events. An EventSource instance opens a persistent connection to an HTTP server, which sends events in `text/event-stream` format.
class EventSource {
  /// Event name for a block in case no `event:` line was seen.
  static const _DEFAULT_EVENT_NAME = 'message';

  /// Expected mime type of an EventSource endpoint.
  static const _MIME_TYPE = 'text/event-stream';

  /// readyState: connection setup in progress.
  static const int CONNECTING = 0;

  /// readyState: connection complete.
  static const int OPEN = 1;

  /// readyState: connection closed.
  static const int CLOSED = 2;

  /// Client used for the request.
  HttpClient? _client;

  /// Random number sequence for exponential backoff.
  final Random _random = Random();

  /// Data controller for the `.events` attribute.
  late StreamController<MessageEvent> _streamController;

  /// Mutable readyState.
  int _readyState = CLOSED;

  /// Time to wait for reconnect after a successful connection.
  Duration? initialReconnectDelay;

  /// Maximum time to wait before reconnecting.
  final Duration? maxReconnectDelay;

  /// Time to wait before next reconnection, null represents initial timout.
  Duration? _reconnectDelay;

  /// Timer used while waiting to reconnect.
  Timer? _reconnecting;

  /// The last-seen event ID, used when reconnecting.
  String? _lastEventID;

  /// The `event:` value for the current block.
  String? _nextEventName;

  /// The data value for the current block.
  String? _nextData;

  /// The function used to create HttpClient when connecting.
  HttpClientFactory? clientFactory;

  /// The URL of the EventSource endpoint.
  final Uri? url;

  /// A number representing the state of the connection.
  int get readyState => _readyState;

  /// A stream of events coming in from the endpoint.
  Stream<MessageEvent> get events => _streamController.stream;

  /// Create an EventSource for a given remote URL.
  EventSource(this.url,
      {this.clientFactory,
      this.initialReconnectDelay = const Duration(seconds: 1),
      this.maxReconnectDelay = const Duration(minutes: 1)})
      : assert(url != null),
        assert(initialReconnectDelay != null),
        assert(maxReconnectDelay != null) {
    if (clientFactory == null) {
      clientFactory = () {
        return HttpClient();
      };
    }
    _streamController = StreamController.broadcast(
      onListen: () {
        open();
      },
      onCancel: () {
        close();
      },
    );
  }

  /// Opens the connection. Once the returned Future completes, events will start coming in on the `.events` attribute.
  Future<Null> open() async {
    if (_readyState != CLOSED) return;
    if (_reconnecting != null) {
      _reconnecting!.cancel();
      _reconnecting = null;
    }

    _readyState = CONNECTING;

    _client = clientFactory!();

    final request = await _client!.getUrl(url!);
    request.headers.set('Accept', _MIME_TYPE);
    if (_lastEventID != null) {
      request.headers.set('Last-Event-ID', _lastEventID!);
    }

    final response = await request.close();
    if (response.statusCode == HttpStatus.noContent) {
      close();
      return;
    }
    if (response.statusCode != HttpStatus.ok) {
      _reconnect();
      return;
    }

    _readyState = OPEN;
    _reconnectDelay = null;

    // One or both of "done" and "error" events can trigger. Ensure reconnect
    // is only called once per connection.
    var reconnectOnce = _onceFunc(_reconnect);
    utf8.decoder.bind(response).transform(LineSplitter()).listen(_onMessage,
        onDone: reconnectOnce as void Function()?, onError: (_) {
      reconnectOnce();
    });
  }

  /// Closes the connection, if any, and sets the `readyState` attribute to `CLOSED`.
  /// If the connection is already closed, the method does nothing.
  void close() {
    if (_reconnecting != null) {
      _reconnecting!.cancel();
      _reconnecting = null;
    }

    if (_readyState != CLOSED) {
      _client!.close(force: true);
      _client = null;
      _readyState = CLOSED;
    }
  }

  /// Start a reconnect timer.
  void _reconnect() {
    close();
    _reconnectDelay ??= initialReconnectDelay;
    _reconnecting = Timer(_reconnectDelay!, () {
      _reconnecting = null;
      if (_readyState == CLOSED) {
        open().catchError((err) {
          _reconnect();
        });
      }
    });
    _reconnectDelay = _reconnectDelay! * (1.5 + _random.nextDouble());
    if (_reconnectDelay! > maxReconnectDelay!) {
      _reconnectDelay = maxReconnectDelay;
    }
  }

  /// Process a partial message (a line).
  void _onMessage(String message) {
    if (message == '') {
      if (_nextEventName == null && _nextData == null) {
        return;
      }

      _streamController.add(MessageEvent(
        name: _nextEventName ?? _DEFAULT_EVENT_NAME,
        data: _nextData,
      ));
      _nextEventName = null;
      _nextData = null;
      return;
    }
    if (message.startsWith(':')) {
      // comment
      return;
    }

    String name = message;
    String? value;
    final colon = message.indexOf(':');
    if (colon != -1) {
      name = message.substring(0, colon);
      value =
          message.substring(message[colon + 1] == ' ' ? colon + 2 : colon + 1);
    }

    if (name == 'event') {
      _nextEventName = value;
    } else if (name == 'data') {
      if (_nextData == null) {
        _nextData = value;
      } else {
        _nextData = _nextData! + '\n$value';
      }
    } else if (name == 'id') {
      _lastEventID = value;
    } else if (name == 'retry') {
      try {
        final Duration d = Duration(
          milliseconds: int.parse(value!, radix: 10),
        );
        initialReconnectDelay = d;
      } catch (_) {
        _reconnect();
      }
    }
  }
}

/// Adapt a function so it will only be called once.
Function _onceFunc(Function f) {
  bool done = false;
  return () {
    if (done) return;
    done = true;
    f();
  };
}
