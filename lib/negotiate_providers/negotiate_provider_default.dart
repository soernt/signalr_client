import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:signalr_client/http_connection.dart';
import 'package:signalr_client/negotiate_providers/i_negotiate_provider.dart';
import 'package:signalr_client/signalr_http_client.dart';

import '../errors.dart';
import '../ihub_protocol.dart';

/// The default negotitate method of SignalR.
class NegotiateProviderDefault extends INegotiateProvider {
  @override
  Future<NegotiateResponse> getNegotiateResponse(String url, SignalRHttpClient httpClient, Logger logger, {String authorizationToken}) async {
    MessageHeaders headers = MessageHeaders();
    if (authorizationToken != null) {
      headers.setHeaderValue("Authorization", "Bearer $authorizationToken");
    }

    final negotiateUrl = _resolveNegotiateUrl(url);
    logger?.finer("Sending negotiation request: $negotiateUrl");
    try {
      final SignalRHttpRequest options = SignalRHttpRequest(content: "", headers: headers);
      final response = await httpClient.post(negotiateUrl, options: options);

      if (response.statusCode != 200) {
        throw GeneralError("Unexpected status code returned from negotiate $response.statusCode");
      }

      if (!(response.content is String)) {
        throw GeneralError("Negotation response content must be a json.");
      }
      return NegotiateResponse.fromJson(json.decode(response.content as String));
    } catch (e) {
      logger?.severe("Failed to complete negotiation with the server: ${e.toString()}");
      throw e;
    }
  }

  static String _resolveNegotiateUrl(String url) {
    final index = url.indexOf("?");
    var negotiateUrl = url.substring(0, index == -1 ? url.length : index);
    if (negotiateUrl[negotiateUrl.length - 1] != "/") {
      negotiateUrl += "/";
    }
    negotiateUrl += "negotiate";
    negotiateUrl += index == -1 ? "" : url.substring(index);
    return negotiateUrl;
  }
}
