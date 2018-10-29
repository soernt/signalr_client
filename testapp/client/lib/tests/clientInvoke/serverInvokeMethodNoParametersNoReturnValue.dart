import 'package:client/tests/test.dart';
import 'package:client/views/pages/testsPageViewModel.dart';
import 'package:logging/logging.dart';
import 'package:signalr_client/signalr_client.dart';

class ServerInvokeMethodNoParametersNoReturnValue extends Test {
  // Properties

  // Methods
  ServerInvokeMethodNoParametersNoReturnValue(HubConnectionProvider hubConnectionProvider, Logger logger)
      : super(hubConnectionProvider, logger, "Server Invokes method: 'ServerInvokeMethodNoParametersNoReturnValue");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    hubConnection.on("ServerInvokeMethodNoParametersNoReturnValue", _handleServerInvokeMethodNoParametersNoReturnValue);
    try {
      await hubConnection.invoke("ServerInvokeMethodNoParametersNoReturnValue");
    } finally {
      hubConnection.off("ServerInvokeMethodNoParametersNoReturnValue", method: _handleServerInvokeMethodNoParametersNoReturnValue);
    }
  }

  void _handleServerInvokeMethodNoParametersNoReturnValue(List<Object> parameters) {
    logger.info("From Callback: Server invoked method 'ServerInvokeMethodNoParametersNoReturnValue'");
  }
}
