import '../../views/pages/testsPageViewModel.dart';
import '../test.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

class ServerInvokeMethodSimpleParametersNoReturnValue extends Test {
  // Properties

  // Methods
  ServerInvokeMethodSimpleParametersNoReturnValue(
      HubConnectionProvider hubConnectionProvider, Logger logger)
      : super(hubConnectionProvider, logger,
            "Server Invokes method: 'ServerInvokeMethodSimpleParametersNoReturnValue");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    hubConnection.on("ServerInvokeMethodSimpleParametersNoReturnValue",
        _handleServerInvokeMethodSimpleParametersNoReturnValue);
    try {
      await hubConnection
          .invoke("ServerInvokeMethodSimpleParametersNoReturnValue");
    } finally {
      hubConnection.off("ServerInvokeMethodSimpleParametersNoReturnValue",
          method: _handleServerInvokeMethodSimpleParametersNoReturnValue);
    }
  }

  void _handleServerInvokeMethodSimpleParametersNoReturnValue(
      List<Object?>? parameters) {
    final paramValues = new StringBuffer("Parameters: ");
    for (int i = 0; i < parameters!.length; i++) {
      final value = parameters[i];
      paramValues.write("$i => $value, ");
    }

    logger.info(
        "From Callback: Server invoked method 'ServerInvokeMethodSimpleParametersNoReturnValue': " +
            paramValues.toString());
  }
}
