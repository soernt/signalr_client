import 'package:client/main.dart';
import 'package:client/tests/tests.dart';
import 'package:client/utils/signalRLogger.dart';
import 'package:client/utils/viewModel/viewModel.dart';
import 'package:client/utils/viewModel/viewModelProvider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signalr_client/signalr_client.dart';

typedef HubConnectionProvider = Future<HubConnection> Function();

class TestsPageViewModel extends ViewModel {
// Properties
  SignalRLogger _logger;
  Tests _tests;
  String _serverUrl;
  HubConnection _hubConnection;

  String _errorMessage;
  static const String errorMessagePropName = "errorMessage";
  String get errorMessage => _errorMessage;
  set errorMessage(String value) {
    updateValue(errorMessagePropName, _errorMessage, value, (v) => _errorMessage = v);
  }

  List<LogMessage> _hubLogMessages;
  static const String hubLogMessagesPropName = "hubLogMessages";
  List<LogMessage> get hubLogMessages => _hubLogMessages;

  Tests get tests => _tests;

// Methods
  TestsPageViewModel() {
    _hubLogMessages = List<LogMessage>();
    _logger = SignalRLogger(_logHubMessage);
    _serverUrl = kServerUrl + "/IntegrationTestHub";
    _tests = Tests(_getHubConnection, _logger);
  }

  void _logHubMessage(LogMessage msg) {
    _hubLogMessages.add(msg);
    notifyPropertyChanged(hubLogMessagesPropName);
  }

  Future<HubConnection> _getHubConnection() async {
    if (_hubConnection == null) {
      final httpOptions = new HttpConnectionOptions(logger: _logger);
      //final httpOptions = new HttpConnectionOptions(logger: _logger, transport: HttpTransportType.ServerSentEvents);
      //final httpOptions = new HttpConnectionOptions(logger: _logger, transport: HttpTransportType.LongPolling);

      
      _hubConnection = HubConnectionBuilder().withUrl(_serverUrl, options: httpOptions).configureLogging(logger: _logger).build();
      _hubConnection.onclose( (error) => _logger.log(LogLevel.Trace, "Connection Closed"));
    }

    if(_hubConnection.state != HubConnectionState.Connected){
      await _hubConnection.start();
      _logger.log(LogLevel.Trace, "Connection state '${_hubConnection.state}'");
    }

    return _hubConnection;
  }

  Future<void> connect() async {
    try {} catch (e) {
      errorMessage = e.toString();
    }
  }

  clearLogs() {
    _hubLogMessages.clear();
    notifyPropertyChanged(hubLogMessagesPropName);
  }
}

class TestsPageViewModelProvider extends ViewModelProvider<TestsPageViewModel> {
  // Properties

  // Methods
  TestsPageViewModelProvider({Key key, viewModel: TestsPageViewModel, WidgetBuilder childBuilder}) : super(key: key, viewModel: viewModel, childBuilder: childBuilder);

  static TestsPageViewModel of(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(TestsPageViewModelProvider) as TestsPageViewModelProvider).viewModel;
  }
}
