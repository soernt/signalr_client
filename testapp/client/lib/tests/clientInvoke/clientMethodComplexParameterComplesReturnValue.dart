import 'dart:async';

import 'package:client/tests/test.dart';
import 'package:client/views/pages/testsPageViewModel.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

class ClientMethodComplexParameterComplexReturnValue extends Test {
  // Properties

  // Methods
  ClientMethodComplexParameterComplexReturnValue(
      HubConnectionProvider hubConnectionProvider, Logger logger)
      : super(hubConnectionProvider, logger,
            "Client Invokes method 'MethodWithComplexParameterAndComplexReturnValue");

  @override
  Future<void> executeTest(HubConnection hubConnection) async {
    var reqParam =
        new ComplexInParameter(firstName: 'Fred', lastName: 'Finstone');
    final jsonResult = await hubConnection.invoke(
        "MethodWithComplexParameterAndComplexReturnValue",
        args: <Object>[reqParam]);
    var resultObj = ComplexReturnValue.fromJson(jsonResult);
    logger.info("Result: '$resultObj");
  }
}

class ComplexInParameter {
  String firstName;
  String lastName;

  ComplexInParameter({
    this.firstName,
    this.lastName,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
      };
}

class ComplexReturnValue {
  String firstName;
  String lastName;
  String greetingText;

  ComplexReturnValue({this.firstName, this.lastName, this.greetingText});

  factory ComplexReturnValue.fromJson(Map<String, dynamic> json) {
    return ComplexReturnValue(
        firstName: json['firstName'] ?? '',
        lastName: json['lastName'] ?? '',
        greetingText: json['greetingText']);
  }

  @override
  String toString() {
    return 'firstName: "$firstName", lastName: "$lastName", greetingText: "$greetingText"';
  }
}
