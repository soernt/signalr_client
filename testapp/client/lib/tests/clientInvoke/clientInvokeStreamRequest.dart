import '../../views/pages/testsPageViewModel.dart';
import '../test.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

class ClientInvokeStreamRequest extends Test {
  // Properties

  // Methods
  ClientInvokeStreamRequest(
      HubConnectionProvider hubConnectionProvider, Logger logger)
      : super(hubConnectionProvider, logger,
            "Client invoke Stream request 'StreamCounterValuesToClient'");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    final stream = hubConnection
        .stream('StreamCounterValuesToClient', <Object>[10, 1 * 500]);
    try {
      stream.forEach((item) {
        logger.info("Server stream value: '${item.toString()}'");
      });
    } catch (e) {
      logger.severe(e.toString());
    }
  }
}
