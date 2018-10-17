import 'errors.dart';
import 'http_connection.dart';
import 'http_connection_options.dart';
import 'hub_connection.dart';
import 'ihub_protocol.dart';
import 'ilogger.dart';
import 'itransport.dart';
import 'json_hub_protocol.dart';
import 'utils.dart';

/// A builder for configuring {@link @aspnet/signalr.HubConnection} instances.
class HubConnectionBuilder {
  // Properties

  IHubProtocol _protocol;

  HttpConnectionOptions _httpConnectionOptions;

  String _url;

  ILogger _logger;

  /// Configures console logging for the HubConnection.
  ///
  /// logLevel: The minimum level of messages to log. Anything at this level, or a more severe level, will be logged.
  /// logger: this logger with the already configured log level will be used.
  /// Either the logLevel will be used with a new instance of a ConsoleLogger or the given logger will be used.
  /// Returns the builder instance, for chaining.
  ///
  HubConnectionBuilder configureLogging({LogLevel logLevel, ILogger logger}) {
    if (logLevel == null) {
      logLevel = LogLevel.Error;
    }

    if (logger == null) {
      _logger = ConsoleLogger(logLevel);
    } else
    {
      _logger = logger;
    }
    return this;
  }

  /// Configures the {@link @aspnet/signalr.HubConnection} to use HTTP-based transports to connect to the specified URL.
  ///
  /// url: The URL the connection will use.
  /// options: An options object used to configure the connection.
  /// transportType: The requested (and supported) transportedType.
  /// Use either options or transportType.
  /// Returns the builder instance, for chaining.
  ///
  HubConnectionBuilder withUrl(String url, {HttpConnectionOptions options, HttpTransportType transportTyp}) {
    assert(!isStringEmpty(url));
    assert(!(options != null && transportTyp != null));

    _url = url;

    if (options != null) {
      _httpConnectionOptions = options;
    } else {
      _httpConnectionOptions = HttpConnectionOptions(transport: transportTyp);
    }

    return this;
  }

  /// Configures the HubConnection to use the specified Hub Protocol.
  ///
  /// protocol: The IHubProtocol implementation to use.
  ///
  HubConnectionBuilder withHubProtocol(IHubProtocol protocol) {
    assert(protocol != null);

    _protocol = protocol;
    return this;
  }

  /// Creates a HubConnection from the configuration options specified in this builder.
  ///
  /// Returns the configured HubConnection.
  ///
  HubConnection build() {
    // If httpConnectionOptions has a logger, use it. Otherwise, override it with the one
    // provided to configureLogger
    final httpConnectionOptions = _httpConnectionOptions ?? HttpConnectionOptions();

    // Now create the connection
    if (isStringEmpty(_url)) {
      throw new GeneralError("The 'HubConnectionBuilder.withUrl' method must be called before building the connection.");
    }
    final connection = HttpConnection(_url, options: httpConnectionOptions);
    return HubConnection(connection, _logger ?? NullLogger.instance, _protocol ?? JsonHubProtocol());
  }
}
