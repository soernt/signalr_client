import 'dart:async';

import 'package:chatclient/main.dart';
import 'package:chatclient/utils/viewModel/viewModel.dart';
import 'package:chatclient/utils/viewModel/viewModelProvider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signalr_client/signalr_client.dart';
import 'package:logging/logging.dart';

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
    updateValue(connectionIsOpenPropName, _connectionIsOpen, value, (v) => _connectionIsOpen = v);
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
    _chatMessages = List<ChatMessage>();
    _connectionIsOpen = false;
    _userName = "Fred";

    Logger.root.level = Level.ALL;
    _logMessagesSub = Logger.root.onRecord.listen(_handleLogMessage);
    _logger = Logger("ChatPageViewModel");

    openChatConnection();
  }

  void _handleLogMessage(LogRecord msg) {
    print(msg.message);
  }

  Future<void> openChatConnection() async {
    final logger = _logger;

    if (_hubConnection == null) {
      final httpConnectionOptions = new HttpConnectionOptions(logger: logger, logMessageContent: true);

      _hubConnection = HubConnectionBuilder()
        .withUrl(_serverUrl, options: httpConnectionOptions)
        .withAutomaticReconnect()
        .configureLogging(logger)
        .build();
      _hubConnection.onclose(({error}) => connectionIsOpen = false);
      _hubConnection.onreconnecting(({error}) {
        print("onreconnecting called");
        connectionIsOpen = false;
      });
      _hubConnection.onreconnected(({connectionId}) {
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
    if( chatMessage == null ||chatMessage.length == 0){
      return;
    }
    await openChatConnection();
    _hubConnection.invoke("Send", args: <Object>[userName, chatMessage] );
  }

  void _handleIncommingChatMessage(List<Object> args){
    final String senderName = args[0];
    final String message = args[1];
    _chatMessages.add( ChatMessage(senderName, message));
    notifyPropertyChanged(chatMessagesPropName);
  }
}

class ChatPageViewModelProvider extends ViewModelProvider<ChatPageViewModel> {
  // Properties

  // Methods
  ChatPageViewModelProvider({Key key, viewModel: ChatPageViewModel, WidgetBuilder childBuilder}) : super(key: key, viewModel: viewModel, childBuilder: childBuilder);

  static ChatPageViewModel of(BuildContext context) {
    return (context.dependOnInheritedWidgetOfExactType<ChatPageViewModelProvider>()).viewModel;
  }
}
