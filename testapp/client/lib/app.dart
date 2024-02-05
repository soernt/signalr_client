import 'package:flutter/material.dart';

import 'views/pages/testsPage.dart';

class App extends StatelessWidget {
  // Properties

  // Methods
  App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: TestsPage(),
    );
  }
}
