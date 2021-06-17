import 'package:http/browser_client.dart';

final clientWithWebSupport = BrowserClient()..withCredentials = true;
