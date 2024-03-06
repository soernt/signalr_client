import '../../views/pages/testsPageViewModel.dart';
import '../test.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

class ClientMethodOneSimpleParameterNoReturnValue extends Test {
  // Properties

  // Methods
  ClientMethodOneSimpleParameterNoReturnValue(
      HubConnectionProvider hubConnectionProvider, Logger logger)
      : super(hubConnectionProvider, logger,
            "Client Invokes method 'MethodOneSimpleParameterNoReturnValue");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    await hubConnection.invoke("MethodOneSimpleParameterNoReturnValue",
        args: <Object>["ParameterValue"]);
  }
}
