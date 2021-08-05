import 'package:logging/logging.dart';
import 'package:signalr_netcore/exceptions/errors.dart';
import 'package:signalr_netcore/policies/default_reconnect_policy.dart';
import 'package:signalr_netcore/policies/iretry_policy.dart';
import 'package:signalr_netcore/protocols/ihub_protocol.dart';
import 'package:signalr_netcore/protocols/json_hub_protocol.dart';
import 'package:signalr_netcore/transport/itransport.dart';
import 'package:signalr_netcore/utils/utils.dart';

import 'http_connection.dart';
import 'http_connection_options.dart';
import 'hub_connection.dart';

/// A builder for configuring {@link @microsoft/signalr.HubConnection} instances.
class HubConnectionBuilder {
  // Properties

  IHubProtocol _protocol;

  HttpConnectionOptions _httpConnectionOptions;

  String _url;

  Logger _logger;

  /// If defined, this indicates the client should automatically attempt to reconnect if the connection is lost. */
  ///
  IRetryPolicy _reconnectPolicy;

  /// Configures console logging for the HubConnection.
  ///
  /// logger: this logger with the already configured log level will be used.
  /// Returns the builder instance, for chaining.
  ///
  HubConnectionBuilder configureLogging(Logger logger) {
    _logger = logger;
    return this;
  }

  /// Configures the {@link @microsoft/signalr.HubConnection} to use HTTP-based transports to connect to the specified URL.
  ///
  /// url: The URL the connection will use.
  /// options: An options object used to configure the connection.
  /// transportType: The requested (and supported) transportedType.
  /// Use either options or transportType.
  /// Returns the builder instance, for chaining.
  ///
  HubConnectionBuilder withUrl(String url,
      {HttpConnectionOptions options, HttpTransportType transportType}) {
    assert(!isStringEmpty(url));
    assert(!(options != null && transportType != null));

    _url = url;

    if (options != null) {
      _httpConnectionOptions = options;
    } else {
      _httpConnectionOptions = HttpConnectionOptions(transport: transportType);
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

  HubConnectionBuilder withAutomaticReconnect(
      {IRetryPolicy reconnectPolicy, List<int> retryDelays}) {
    assert(_reconnectPolicy == null);

    if (reconnectPolicy == null && retryDelays == null) {
      _reconnectPolicy = DefaultRetryPolicy();
    } else if (retryDelays != null) {
      _reconnectPolicy = DefaultRetryPolicy(retryDelays: retryDelays);
    } else {
      _reconnectPolicy = reconnectPolicy;
    }

    return this;
  }

  /// Creates a HubConnection from the configuration options specified in this builder.
  ///
  /// Returns the configured HubConnection.
  ///
  HubConnection build() {
    // If httpConnectionOptions has a logger, use it. Otherwise, override it with the one
    // provided to configureLogger
    final httpConnectionOptions =
        _httpConnectionOptions ?? HttpConnectionOptions();

    // Now create the connection
    if (isStringEmpty(_url)) {
      throw new GeneralError(
          "The 'HubConnectionBuilder.withUrl' method must be called before building the connection.");
    }
    final connection = HttpConnection(_url, options: httpConnectionOptions);
    return HubConnection.create(
        connection, _logger, _protocol ?? JsonHubProtocol(),
        reconnectPolicy: _reconnectPolicy);
  }
}
