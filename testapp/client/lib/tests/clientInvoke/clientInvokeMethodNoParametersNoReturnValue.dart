import 'package:client/tests/test.dart';
import 'package:client/views/pages/testsPageViewModel.dart';
import 'package:signalr_client/signalr_client.dart';

class ClientMethodNoParametersNoReturnValue extends Test {
  // Properties

  // Methods
  ClientMethodNoParametersNoReturnValue(HubConnectionProvider hubConnectionProvider, ILogger logger) : super(hubConnectionProvider, logger, "Client Invokes method: 'MethodNoParametersNoReturnValue");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    await hubConnection.invoke("MethodNoParametersNoReturnValue");
  }
}
