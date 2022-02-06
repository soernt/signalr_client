# signalr_client

[![pub package](https://img.shields.io/pub/v/signalr_netcore.svg)](https://pub.dartlang.org/packages/signalr_netcore)

A Flutter SignalR Client for [ASP.NET Core 3.1](https://docs.microsoft.com/aspnet/core/signalr/?view=aspnetcore-3.1).   
ASP.NET Core SignalR is an open-source library that simplifies adding real-time web functionality to apps. Real-time web functionality enables server-side code to push content to clients instantly.

The client is able to invoke server side hub functions (including streaming functions) and to receive method invocations issued by the server.  It also supports the auto-reconnect feature.

The client supports the following transport protocols:
* WebSocket
* Service Side Events
* Long Polling

The client supports the following hub protocols:
* Json
* [~~MessagePack~~](https://msgpack.org/) - Since I can't find a MessagePack library that support the current flutter version.

## Examples

* [Chat client/server](https://github.com/sefidgaran/signalr_client/tree/master/example) - A simple client/server chat application.
* [Integration test app](https://github.com/sefidgaran/signalr_client/tree/master/testapp/client) - To see how a client calls various types of hub functions.
  

## Getting Started

Add `signalr_netcore` to your `pubspec.yaml` dependencies:
```yaml
...
dependencies:
  flutter:
    sdk: flutter

  signalr_netcore:
...
```

Important Note: if you are experiencing issues (for example not receiving message callback) with the latest version, please give a try to older version as signalr_netcore: 0.1.7+2-nullsafety.3 but bear in mind that this version does not support auto reconnect functionalities and need to be handled manually.

## Usage

Let's demo some basic usages:

#### 1. Create a hub connection:
```dart
// Import the library.
import 'package:signalr_netcore/signalr_client.dart';

// The location of the SignalR Server.
final serverUrl = "192.168.10.50:51001";
// Creates the connection by using the HubConnectionBuilder.
final hubConnection = HubConnectionBuilder().withUrl(serverUrl).build();
// When the connection is closed, print out a message to the console.
final hubConnection.onclose( (error) => print("Connection Closed"));

```
Logging is supported via the dart [logging package](https://pub.dartlang.org/packages/logging):

```dart
// Import theses libraries.
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

// Configer the logging
Logger.root.level = Level.ALL;
// Writes the log messages to the console
Logger.root.onRecord.listen((LogRecord rec) {
  print('${rec.level.name}: ${rec.time}: ${rec.message}');
});

// If you want only to log out the message for the higer level hub protocol:
final hubProtLogger = Logger("SignalR - hub");
// If youn want to also to log out transport messages:
final transportProtLogger = Logger("SignalR - transport");

// The location of the SignalR Server.
final serverUrl = "192.168.10.50:51001";
final connectionOptions = HttpConnectionOptions
final httpOptions = new HttpConnectionOptions(logger: transportProtLogger);
//final httpOptions = new HttpConnectionOptions(logger: transportProtLogger, transport: HttpTransportType.WebSockets); // default transport type.
//final httpOptions = new HttpConnectionOptions(logger: transportProtLogger, transport: HttpTransportType.ServerSentEvents);
//final httpOptions = new HttpConnectionOptions(logger: transportProtLogger, transport: HttpTransportType.LongPolling);

// If you need to authorize the Hub connection than provide a an async callback function that returns 
// the token string (see AccessTokenFactory typdef) and assigned it to the accessTokenFactory parameter:
// final httpOptions = new HttpConnectionOptions( .... accessTokenFactory: () async => await getAccessToken() ); 

// Creates the connection by using the HubConnectionBuilder.
final hubConnection = HubConnectionBuilder().withUrl(serverUrl, options: httpOptions).configureLogging(hubProtLogger).build();
// When the connection is closed, print out a message to the console.
final hubConnection.onclose( (error) => print("Connection Closed"));

```
#### 2. Connect to a Hub:
Calling following method starts handshaking and connects the client to SignalR server
```c
await hubConnection.start();
```


#### 3. Calling a Hub function:

Assuming there is this hub function:
```c
public string MethodOneSimpleParameterSimpleReturnValue(string p1)
{
  Console.WriteLine($"'MethodOneSimpleParameterSimpleReturnValue' invoked. Parameter value: '{p1}");
  return p1;
}
```

The client can invoke the function by using:

```dart

  final result = await hubConnection.invoke("MethodOneSimpleParameterSimpleReturnValue", args: <Object>["ParameterValue"]);
  logger.log(LogLevel.Information, "Result: '$result");

```


#### 4. Calling a client function:

Assuming the server calls a function "aClientProvidedFunction":
```c
  await Clients.Caller.SendAsync("aClientProvidedFunction", null);
```

The Client provides the function like this:

```dart
  
  hubConnection.on("aClientProvidedFunction", _handleAClientProvidedFunction);

  // To unregister the function use:
  // a) to unregister a specific implementation:
  // hubConnection.off("aClientProvidedFunction", method: _handleServerInvokeMethodNoParametersNoReturnValue);
  // b) to unregister all implementations:
  // hubConnection.off("aClientProvidedFunction");
  ...
  void _handleAClientProvidedFunction(List<Object> parameters) {
    logger.log(LogLevel.Information, "Server invoked the method");
  }

```

### A note about the parameter types

All function parameters and return values are serialized/deserialized into/from JSON by using the dart:convert package (json.endcode/json.decode). Make sure that you:
* use only simple parameter types

or

* use objects that implements toJson() since that method is used by the dart:convert package to serialize an object.


Flutter Json 101: 
* [flutter.io](https://flutter.io/json/)
* [json.encode](https://api.dartlang.org/stable/2.0.0/dart-convert/JsonCodec/encode.html)
* [json.decode](https://api.dartlang.org/stable/2.0.0/dart-convert/JsonCodec/decode.html)


### How to expose a MessageHeaders object so the client can send default headers

Code Example:

```dart
final defaultHeaders = MessageHeaders();
defaultHeaders.setHeaderValue("HEADER_MOCK_1", "HEADER_VALUE_1");
defaultHeaders.setHeaderValue("HEADER_MOCK_2", "HEADER_VALUE_2");

final httpConnectionOptions = new HttpConnectionOptions(
          httpClient: WebSupportingHttpClient(logger,
              httpClientCreateCallback: _httpClientCreateCallback),
          accessTokenFactory: () => Future.value('JWT_TOKEN'),
          logger: logger,
          logMessageContent: true,
          headers: defaultHeaders);

final _hubConnection = HubConnectionBuilder()
          .withUrl(_serverUrl, options: httpConnectionOptions)
          .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000, null])
          .configureLogging(logger)
          .build();
```

Http Request Log:

```
I/flutter ( 5248): Starting connection with transfer format 'TransferFormat.Text'.
I/flutter ( 5248): Sending negotiation request: https://localhost:5000/negotiate?negotiateVersion=1
I/flutter ( 5248): HTTP send: url 'https://localhost:5000/negotiate?negotiateVersion=1', method: 'POST' content: '' content length = '0' 
headers: '{ content-type: text/plain;charset=UTF-8 }, { HEADER_MOCK_1: HEADER_VALUE_1 }, { X-Requested-With: FlutterHttpClient }, { HEADER_MOCK_2: HEADER_VALUE_2 }, { Authorization: Bearer JWT_TOKEN }'
```