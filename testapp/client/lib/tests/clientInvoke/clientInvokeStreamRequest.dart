import 'package:client/tests/test.dart';
import 'package:client/views/pages/testsPageViewModel.dart';
import 'package:signalr_client/signalr_client.dart';

class ClientInvokeStreamRequest extends Test {
  // Properties

  // Methods
  ClientInvokeStreamRequest(HubConnectionProvider hubConnectionProvider, ILogger logger) : super(hubConnectionProvider, logger, "Client invoke Stream request 'StreamCounterValuesToClient'");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    final stream = hubConnection.stream('StreamCounterValuesToClient', <Object>[10, 1 * 500]);
    try {
      stream.forEach((item) {
        logger.log(LogLevel.Information, "Server stream value: '${item.toString()}'");
      });
    } catch (e) {
      logger.log(LogLevel.Error, e.toString());
    }
  }
}
