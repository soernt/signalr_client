import 'dart:async';

import 'package:logging/logging.dart';

import '../http_connection.dart';
import '../itransport.dart';
import '../signalr_http_client.dart';

abstract class INegotiateProvider {
  Future<NegotiateResponse> getNegotiateResponse(String url, SignalRHttpClient signalRHttpClient, Logger logger, {String authorizationToken});
}