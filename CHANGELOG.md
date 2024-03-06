  
## [1.3.7]

* Update dependencies using http: ^1.1.0
  
## [1.3.6]

* Emit events once the HubConnectionState changes

## [1.3.5]

* Upgrade packages and remove warnings
  
## [1.3.4]

* Fix the disconnect exception caused by send message error
  
## [1.3.3]

* Allowing invocation arguments to be null

## [1.3.2]

* Fix broken authorization in SSE (Server Side Events) transport

## [1.3.1]

* Add MessagePack with WEB support.

## [1.3.0]

* Add Msgpack support and added some tests.
* Migrate examples to ASP NET core 6

## [1.2.6]
* Add Timeout option for requests to resolve unexpected Timeout Exceptions  

## [1.2.5]
* Migrate examples to Android embedding v2

## [1.2.4+1]
* Fix formatting issues 

## [1.2.4] 
* Update readme
* Exposes default MessageHeaders for HttpRequests
* Remove warnings

## [1.2.3+1] 
* Update readme

## [1.2.3]
* Fix on error calling onReceive, error: type 'List' is not a subtype of type 'List?'
* Fix an error when CompletionMessage doesn't have error and returns null on result property.

## [1.2.2]
* Bug fix

## [1.2.1+1]
* Fix all flutter formatting issues

## [1.2.1]
* Fix formatting issues

## [1.2.0]
* Null safety migration

## [1.1.1]
* Fix pub.dev evaluation result for native support

## [1.1.0]
* Add support for web
* Bug fixes

## [1.0.1]
* Upgrade packages

## [1.0.0]
* Upgrade to Flutter 2

## [0.1.8+2]
* Dart format files

## [0.1.8+1]
* Move chat client files to example folder
* Add dispose to chat client example view
* Re-format (dart) files

## [0.1.8]
* Align codebase with AspNetCore 3.1 Typescript client codebase, including support for auto-reconnect

## [0.1.7+1]
* Minor changes

## [0.1.7]
* Fix the exception for: Response Content-Type not supported: [application/json; charset=UTF-8]

## [0.1.6]
* Merged pull request "Prepare for Uint8List SDK breaking change"

## [0.1.5]
* Fix complex object serialization to json.

## [0.1.4]
* Prevent null exception when calling HubConnection.stop()

## [0.1.3]
* Change the logging behaviour: The client uses the dart standard [logging](https://pub.dartlang.org/packages/logging) package instead of a proprietary logging behaviour (see readme for an example).
* Fixes a bug within the MessageHeaders class.

## [0.1.2]

* Be more descriptional within the desciption of the pubspec.yaml

## [0.1.1]

* Be more descriptional within the desciption of the pubspec.yaml

## [0.1.0]

* Chat client/server example added.
* Reformat Library code to compile to PUB spec.
* Added some more description to the readme.

## [0.0.1]

* Intitial Version
