import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'main.dart';
import 'utils/viewModel/viewModel.dart';
import 'utils/viewModel/viewModelProvider.dart';

typedef HubConnectionProvider = Future<HubConnection> Function();

class ChatMessage {
  // Properites

  final String senderName;
  final String message;

  // Methods
  ChatMessage(this.senderName, this.message);
}

class ChatPageViewModel extends ViewModel {
// Properties
  String _serverUrl;
  HubConnection _hubConnection;
  Logger _logger;
  StreamSubscription<LogRecord> _logMessagesSub;

  List<ChatMessage> _chatMessages;
  static const String chatMessagesPropName = "chatMessages";
  List<ChatMessage> get chatMessages => _chatMessages;

  bool _connectionIsOpen;
  static const String connectionIsOpenPropName = "connectionIsOpen";
  bool get connectionIsOpen => _connectionIsOpen;
  set connectionIsOpen(bool value) {
    updateValue(connectionIsOpenPropName, _connectionIsOpen, value,
        (v) => _connectionIsOpen = v);
  }

  String _userName;
  static const String userNamePropName = "userName";
  String get userName => _userName;
  set userName(String value) {
    updateValue(userNamePropName, _userName, value, (v) => _userName = v);
  }

// Methods

  ChatPageViewModel() {
    _serverUrl = kChatServerUrl + "/Chat";
    _chatMessages = [];
    _connectionIsOpen = false;
    _userName = "Fred";

    Logger.root.level = Level.ALL;
    _logMessagesSub = Logger.root.onRecord.listen(_handleLogMessage);
    _logger = Logger("ChatPageViewModel");

    openChatConnection();
  }

  @override
  void dispose() {
    _logMessagesSub?.cancel();
    super.dispose();
  }

  void _handleLogMessage(LogRecord msg) {
    print(msg.message);
  }

  void _httpClientCreateCallback(Client httpClient) {
    HttpOverrides.global = HttpOverrideCertificateVerificationInDev();
  }

  Future<void> openChatConnection() async {
    final logger = _logger;

    if (_hubConnection == null) {
      final httpConnectionOptions = new HttpConnectionOptions(
          httpClient: WebSupportingHttpClient(logger,
              httpClientCreateCallback: _httpClientCreateCallback),
          logger: logger,
          logMessageContent: true);

      _hubConnection = HubConnectionBuilder()
          .withUrl(_serverUrl, options: httpConnectionOptions)
          .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000, null])
          .configureLogging(logger)
          .build();
      _hubConnection.onClose((error) => connectionIsOpen = false);
      _hubConnection.onReconnecting(({error}) {
        print("onreconnecting called");
        connectionIsOpen = false;
      });
      _hubConnection.onReconnected(({connectionId}) {
        print("onreconnected called");
        connectionIsOpen = true;
      });
      _hubConnection.on("OnMessage", _handleIncommingChatMessage);
    }

    if (_hubConnection.state != HubConnectionState.Connected) {
      await _hubConnection.start();
      connectionIsOpen = true;
    }
  }

  Future<void> sendChatMessage(String chatMessage) async {
    if (chatMessage == null || chatMessage.length == 0) {
      return;
    }
    await openChatConnection();
    _hubConnection.invoke("Send", args: <Object>[userName, chatMessage]);
  }

  void _handleIncommingChatMessage(List<Object> args) {
    final String senderName = args[0];
    final String message = args[1];
    _chatMessages.add(ChatMessage(senderName, message));
    notifyPropertyChanged(chatMessagesPropName);
  }
}

class ChatPageViewModelProvider extends ViewModelProvider<ChatPageViewModel> {
  // Properties

  // Methods
  ChatPageViewModelProvider(
      {Key key, viewModel: ChatPageViewModel, WidgetBuilder childBuilder})
      : super(key: key, viewModel: viewModel, childBuilder: childBuilder);

  static ChatPageViewModel of(BuildContext context) {
    return (context
            .dependOnInheritedWidgetOfExactType<ChatPageViewModelProvider>())
        .viewModel;
  }
}

class HttpOverrideCertificateVerificationInDev extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
