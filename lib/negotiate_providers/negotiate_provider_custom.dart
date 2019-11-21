import 'dart:async';

import 'package:logging/logging.dart';
import 'package:signalr_client/http_connection.dart';
import 'package:signalr_client/negotiate_providers/i_negotiate_provider.dart';
import 'package:signalr_client/negotiate_providers/negotiate_provider_default.dart';
import 'package:signalr_client/signalr_http_client.dart';

/// The accessToken (JWT) is specified.
/// 
/// The hub url will be the one configured using withUrl() in HubConnectionBuilder.
/// 
/// After that, the negotiation will be made by the default provider.
/// 
/// accessToken: JWT for connecting to the hub.
class NegotiateProviderCustom extends INegotiateProvider {
  NegotiateProviderDefault _negotiateProviderDefault = NegotiateProviderDefault();
  String _accessToken;

  NegotiateProviderCustom(String accessToken) {
    _accessToken = accessToken;
  }

  @override
  Future<NegotiateResponse> getNegotiateResponse(String url, SignalRHttpClient signalRHttpClient, Logger logger, {String authorizationToken}) async {
    // If authorizationToken is found, negotiate using default provider.
    if (authorizationToken != null)
      return await _negotiateProviderDefault.getNegotiateResponse(url, signalRHttpClient, logger, authorizationToken: authorizationToken);
    
    // If authorizationToken is null, issue a redirect response.
    return NegotiateResponse(null, null, url, _accessToken, null);
  }
}