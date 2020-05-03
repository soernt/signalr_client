import 'dart:async';

import 'http_connection.dart';
import "itransport.dart";

class ConnectionFeatures {
  // Properties
  bool inherentKeepAlive;

  // Methods
  ConnectionFeatures(this.inherentKeepAlive);
}

abstract class IConnection {
  ConnectionFeatures features;
  ConnectionState connectionState;
  Future<void> start({TransferFormat transferFormat});
  Future<void> send(Object data);
  Future<void> stop(Exception error);

  OnReceive onreceive;
  OnClose onclose;

  IConnection() : features = ConnectionFeatures(null);
}
