import 'package:client/utils/viewModel/viewModel.dart';
import 'package:client/views/pages/testsPageViewModel.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:signalr_client/signalr_client.dart';

abstract class Test extends ViewModel {
  // Properties

  final HubConnectionProvider _hubConnectionProvider;

  @protected
  final Logger logger;

  final String description;

  bool _isExecuting;
  static const String isExecutingPropName = "isExecuting";
  bool get isExecuting => _isExecuting;
  set isExecuting(bool value) {
    updateValue(isExecutingPropName, _isExecuting, value, (v) => _isExecuting = v);
  }

  String _errorMessage;
  static const String errorMessagePropName = "errorMessage";
  String get errorMessage => _errorMessage;
  set errorMessage(String value) {
    updateValue(errorMessagePropName, _errorMessage, value, (v) => _errorMessage = v);
  }

  // Methods

  Test(HubConnectionProvider hubConnectionProvider, Logger logger, String description)
      : assert(hubConnectionProvider != null),
        assert(logger != null),
        assert(description != null),
        _hubConnectionProvider = hubConnectionProvider,
        this.logger = logger,
        description = description;

  Future<void> run() async {
    isExecuting = true;
    try {
      await executeTest(await _hubConnectionProvider());
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isExecuting = false;
    }
  }

  Future<void> executeTest(HubConnection hubConnection);
}
