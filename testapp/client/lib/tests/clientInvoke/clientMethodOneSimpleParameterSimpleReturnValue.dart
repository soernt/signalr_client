import 'package:client/tests/test.dart';
import 'package:client/views/pages/testsPageViewModel.dart';
import 'package:signalr_client/signalr_client.dart';

class ClientMethodOneSimpleParameterSimpleReturnValue extends Test {
  // Properties

  // Methods
  ClientMethodOneSimpleParameterSimpleReturnValue(HubConnectionProvider hubConnectionProvider, ILogger logger)
      : super(hubConnectionProvider, logger, "Client Invokes method 'MethodOneSimpleParameterSimpleReturnValue");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    final result = await hubConnection.invoke("MethodOneSimpleParameterSimpleReturnValue", args: <Object>["ParameterValue"]);
    logger.log(LogLevel.Information, "Result: '$result");
  }
}
