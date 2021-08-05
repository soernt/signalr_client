import 'package:logging/logging.dart';
import 'package:signalr_netcore/clients/signalr_http_client.dart';
import 'package:signalr_netcore/transport/itransport.dart';

/// Options provided to the 'withUrl' method on HubConnectionBuilder to configure options for the HTTP-based transports.
class HttpConnectionOptions {
  // Properties

  /// An SignalRHttpClient that will be used to make HTTP requests.
  final SignalRHttpClient? httpClient;

  /// An HttpTransportType or ITransport value specifying the transport to use for the connection
  /// If transport is null and the server supports all transport protocols than HttpTransportType.WebSockets is used.
  final Object? transport;

  /// Configures the logger used for logging.
  ///
  /// Provide an Logger instance, and log messages will be logged via that instance
  ///
  final Logger? logger;

  /// A function that provides an access token required for HTTP Bearer authentication.
  final AccessTokenFactory? accessTokenFactory;

  /// A boolean indicating if message content should be logged.
  ///
  /// Message content can contain sensitive user data, so this is disabled by default.
  ///
  final bool logMessageContent;

  /// A boolean indicating if negotiation should be skipped.
  ///
  /// Negotiation can only be skipped when the IHttpConnectionOptions.transport property is set to 'HttpTransportType.WebSockets'.
  ///
  final bool skipNegotiation;

  // Methods
  const HttpConnectionOptions(
      {SignalRHttpClient? httpClient,
      Object? transport,
      Logger? logger,
      AccessTokenFactory? accessTokenFactory,
      bool logMessageContent = false,
      bool skipNegotiation = false})
      : this.httpClient = httpClient,
        this.transport = transport,
        this.logger = logger,
        this.accessTokenFactory = accessTokenFactory,
        this.logMessageContent = logMessageContent,
        this.skipNegotiation = skipNegotiation;

  HttpConnectionOptions copyWith(
          {SignalRHttpClient? httpClient,
          Object? transport,
          Logger? logger,
          AccessTokenFactory? accessTokenFactory,
          bool? logMessageContent,
          bool? skipNegotiation}) =>
      HttpConnectionOptions(
        httpClient: httpClient ?? this.httpClient,
        transport: transport ?? this.transport,
        logger: logger ?? this.logger,
        accessTokenFactory: accessTokenFactory ?? this.accessTokenFactory,
        logMessageContent: logMessageContent ?? this.logMessageContent,
        skipNegotiation: skipNegotiation ?? this.skipNegotiation,
      );
}
