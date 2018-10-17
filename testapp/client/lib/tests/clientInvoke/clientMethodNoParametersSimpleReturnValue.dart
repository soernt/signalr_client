import 'package:client/tests/test.dart';
import 'package:client/views/pages/testsPageViewModel.dart';
import 'package:signalr_client/signalr_client.dart';

class ClientMethodNoParametersSimpleReturnValue extends Test {
  // Properties

  // Methods
  ClientMethodNoParametersSimpleReturnValue(HubConnectionProvider hubConnectionProvider, ILogger logger)
      : super(hubConnectionProvider, logger, "Client Invokes method: 'MethodNoParametersSimpleReturnValue");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    final result = await hubConnection.invoke("MethodNoParametersSimpleReturnValue");
    logger.log(LogLevel.Information, "Result: '$result");
  }
}
