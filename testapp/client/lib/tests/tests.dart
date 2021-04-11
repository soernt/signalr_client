import 'package:client/tests/clientInvoke/clientInvokeMethodNoParametersNoReturnValue.dart';
import 'package:client/tests/clientInvoke/clientInvokeStreamRequest.dart';
import 'package:client/tests/clientInvoke/clientMethodComplexParameterComplesReturnValue.dart';
import 'package:client/tests/clientInvoke/clientMethodNoParametersSimpleReturnValue.dart';
import 'package:client/tests/clientInvoke/clientMethodOneSimpleParameterNoReturnValue.dart';
import 'package:client/tests/clientInvoke/clientMethodOneSimpleParameterSimpleReturnValue.dart';
import 'package:client/tests/clientInvoke/serverInvokeMethodNoParametersNoReturnValue.dart';
import 'package:client/tests/clientInvoke/serverInvokeMethodSimpleParametersNoReturnValue.dart';
import 'package:client/tests/test.dart';
import 'package:client/views/pages/testsPageViewModel.dart';
import 'package:logging/logging.dart';

class Tests {
  // Properties
  List<Test> _items;

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
