import '../views/pages/testsPageViewModel.dart';
import 'clientInvoke/clientInvokeMethodNoParametersNoReturnValue.dart';
import 'clientInvoke/clientInvokeStreamRequest.dart';
import 'clientInvoke/clientMethodComplexParameterComplexReturnValue.dart';
import 'clientInvoke/clientMethodNoParametersSimpleReturnValue.dart';
import 'clientInvoke/clientMethodOneSimpleParameterNoReturnValue.dart';
import 'clientInvoke/clientMethodOneSimpleParameterSimpleReturnValue.dart';
import 'clientInvoke/serverInvokeMethodNoParametersNoReturnValue.dart';
import 'clientInvoke/serverInvokeMethodSimpleParametersNoReturnValue.dart';
import 'test.dart';
import 'package:logging/logging.dart';

class Tests {
  // Properties
  late List<Test> _items;

  // Methods
  List<Test> get items => _items;

  Tests(HubConnectionProvider connectionProvider, Logger logger) {
    _items = [];

    _items
        .add(ClientMethodNoParametersNoReturnValue(connectionProvider, logger));
    _items.add(
        ClientMethodNoParametersSimpleReturnValue(connectionProvider, logger));
    _items.add(ClientMethodOneSimpleParameterNoReturnValue(
        connectionProvider, logger));
    _items.add(ClientMethodOneSimpleParameterSimpleReturnValue(
        connectionProvider, logger));
    _items.add(ClientMethodComplexParameterComplexReturnValue(
        connectionProvider, logger));

    _items.add(ServerInvokeMethodNoParametersNoReturnValue(
        connectionProvider, logger));
    _items.add(ServerInvokeMethodSimpleParametersNoReturnValue(
        connectionProvider, logger));

    _items.add(ClientInvokeStreamRequest(connectionProvider, logger));
  }
}
