import 'package:logging/logging.dart';
import 'package:signalr_netcore/clients/signalr_http_client.dart';
import 'package:signalr_netcore/transport/itransport.dart';

/// Options provided to the 'withUrl' method on HubConnectionBuilder to configure options for the HTTP-based transports.
class HttpConnectionOptions {
  // Properties

  /// An SignalRHttpClient that will be used to make HTTP requests.
  SignalRHttpClient httpClient;

  /// An HttpTransportType or ITransport value specifying the transport to use for the connection
  /// If transport is null and the server supports all transport protocols than HttpTransportType.WebSockets is used.
  Object transport;

  /// Configures the logger used for logging.
  ///
  /// Provide an Logger instance, and log messages will be logged via that instance
  ///
  Logger logger;

  /// A function that provides an access token required for HTTP Bearer authentication.
  AccessTokenFactory accessTokenFactory;

  /// A boolean indicating if message content should be logged.
  ///
  /// Message content can contain sensitive user data, so this is disabled by default.
  ///
  bool logMessageContent;

  /// A boolean indicating if negotiation should be skipped.
  ///
  /// Negotiation can only be skipped when the IHttpConnectionOptions.transport property is set to 'HttpTransportType.WebSockets'.
  ///
  bool skipNegotiation;

  // Methods
  HttpConnectionOptions(
      {SignalRHttpClient httpClient,
      Object transport,
      Logger logger,
      AccessTokenFactory accessTokenFactory,
      bool logMessageContent = false,
      bool skipNegotiation = false})
      : this.httpClient = httpClient,
        this.transport = transport,
        this.logger = logger,
        this.accessTokenFactory = accessTokenFactory,
        this.logMessageContent = logMessageContent,
        this.skipNegotiation = skipNegotiation;
}
