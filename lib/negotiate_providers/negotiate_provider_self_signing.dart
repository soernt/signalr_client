import 'dart:async';

import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:logging/logging.dart';
import 'package:signalr_client/http_connection.dart';
import 'package:signalr_client/negotiate_providers/i_negotiate_provider.dart';
import 'package:signalr_client/negotiate_providers/negotiate_provider_default.dart';
import 'package:signalr_client/signalr_http_client.dart';

/// The accessToken (JWT) will be generated locally using a given secret key.
///
/// The hub url will be the one configured using withUrl() in HubConnectionBuilder.
/// 
/// After generating the JWT, the negotiation will be made by the default provider.
/// 
/// jwtMaxAge: JWT expriation time (default is 30 mins).
/// userId: a specific userid to the client.
class NegotiateProviderSelfSigning extends INegotiateProvider {
  NegotiateProviderDefault _negotiateProviderDefault = NegotiateProviderDefault();
  String _secretKey;
  Duration _jwtMaxAge;
  String _userId;
  NegotiateProviderSelfSigning(String secretKey, {Duration jwtMaxAge, String userId}) {
    _secretKey = secretKey;
    _jwtMaxAge = jwtMaxAge ?? Duration(minutes: 30);
    _userId = userId;
  }
  @override
  Future<NegotiateResponse> getNegotiateResponse(String url, SignalRHttpClient httpClient, Logger logger, {String authorizationToken}) async {
    // If authorizationToken is found, negotiate using default provider.
    if (authorizationToken != null)
      return await _negotiateProviderDefault.getNegotiateResponse(url, httpClient, logger, authorizationToken: authorizationToken);
    
    // If authorizationToken is null, issue a redirect response.
    Map<String, dynamic> extraPayload = {};
    if (_userId != null)
      extraPayload['nameid'] = _userId;
    var claimSet = JwtClaim(audience: <String>[
      url
    ],
    otherClaims: extraPayload,
    maxAge: _jwtMaxAge);
    return NegotiateResponse(null, null, url, issueJwtHS256(claimSet, _secretKey).toString(), null);
  }
}
