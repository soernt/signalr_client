import 'dart:async';

import '../transport/itransport.dart';

class ConnectionFeatures {
  // Properties
  bool? inherentKeepAlive;

  // Methods
  ConnectionFeatures(this.inherentKeepAlive);
}

abstract class IConnection {
  ConnectionFeatures? features;
  String? connectionId;

  late String baseUrl;

  Future<void> start({TransferFormat? transferFormat});
  Future<void> send(Object data);
  Future<void> stop({Exception? error});

  OnReceive? onReceive;
  OnClose? onClose;

  IConnection() : features = ConnectionFeatures(null);
}
