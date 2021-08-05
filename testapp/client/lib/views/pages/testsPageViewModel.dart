import 'dart:async';

import 'package:client/main.dart';
import 'package:client/tests/tests.dart';
import 'package:client/utils/viewModel/viewModel.dart';
import 'package:client/utils/viewModel/viewModelProvider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

typedef HubConnectionProvider = Future<HubConnection> Function();

class TestsPageViewModel extends ViewModel {
// Properties
  Logger _logger;
  StreamSubscription<LogRecord> _logMessagesSub;
  Tests _tests;
  String _serverUrl;
  HubConnection _hubConnection;

  String _errorMessage;
  static const String errorMessagePropName = "errorMessage";
  String get errorMessage => _errorMessage;
  set errorMessage(String value) {
    updateValue(
        errorMessagePropName, _errorMessage, value, (v) => _errorMessage = v);
  }

  List<LogRecord> _hubLogMessages;
  static const String hubLogMessagesPropName = "hubLogMessages";
  List<LogRecord> get hubLogMessages => _hubLogMessages;

  Tests get tests => _tests;

// Methods
  TestsPageViewModel() {
    _hubLogMessages = [];

    Logger.root.level = Level.ALL;
    _logMessagesSub = Logger.root.onRecord.listen(_handleLogMessage);
    _logger = Logger("TestsPageViewModel");

    _serverUrl = kServerUrl + "/IntegrationTestHub";
    _tests = Tests(_getHubConnection, _logger);
  }

  @override
  void dispose() {
    _logMessagesSub.cancel();
    super.dispose();
  }

  void _handleLogMessage(LogRecord msg) {
    _hubLogMessages.add(msg);
    notifyPropertyChanged(hubLogMessagesPropName);
  }

  Future<HubConnection> _getHubConnection() async {
    final logger = _logger;
    //final logger = null;
    if (_hubConnection == null) {
      final httpOptions = new HttpConnectionOptions(logger: logger);
      //final httpOptions = new HttpConnectionOptions(logger: logger, transport: HttpTransportType.ServerSentEvents);
      //final httpOptions = new HttpConnectionOptions(logger: logger, transport: HttpTransportType.LongPolling);

      _hubConnection = HubConnectionBuilder()
          .withUrl(_serverUrl, options: httpOptions)
          .withAutomaticReconnect()
          .configureLogging(logger)
          .build();
      _hubConnection.onClose((error) => _logger.info("Connection Closed"));
    }

    if (_hubConnection.state != HubConnectionState.Connected) {
      await _hubConnection.start();
      _logger.info("Connection state '${_hubConnection.state}'");
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
  TestsPageViewModelProvider(
      {Key key, viewModel: TestsPageViewModel, WidgetBuilder childBuilder})
      : super(key: key, viewModel: viewModel, childBuilder: childBuilder);

  static TestsPageViewModel of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TestsPageViewModelProvider>()
        .viewModel;
  }
}
