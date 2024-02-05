import '../../main.dart';
import '../../tests/test.dart';
import '../../utils/viewModel/viewModelPropertyWidgetBuilder.dart';
import 'testsPageViewModel.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class TestsPage extends StatelessWidget {
// Properties

// Methods

  TestsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vm = new TestsPageViewModel();
    return TestsPageViewModelProvider(
        viewModel: vm,
        childBuilder: (ctx) {
          return Scaffold(
              appBar: AppBar(title: Text("Server at: $kServerUrl")),
              resizeToAvoidBottomInset: false,
              body: TestsPageView());
        });
  }
}

class TestsPageView extends StatelessWidget {
  // Properties

  // Methods

  @override
  Widget build(BuildContext context) {
    final vm = TestsPageViewModelProvider.of(context);
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          _createTestsSection(vm!, context),
          _createLogMessageViewSection(vm, context)
        ]);
  }

  Widget _createTestsSection(TestsPageViewModel vm, BuildContext context) {
    return Expanded(
      child: Card(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Chip(
              avatar: CircleAvatar(
                backgroundColor: Colors.blue.shade800,
                child: Text(vm.tests.items.length.toString()),
              ),
              label: Text("Tests"),
            ),
            Padding(padding: EdgeInsetsDirectional.only(top: 8.0)),
            Expanded(
                child: ListView.builder(
                    itemCount: vm.tests.items.length,
                    itemBuilder: (BuildContext ctx, int index) =>
                        _createTestItemView(vm.tests.items[index]))),
          ],
        ),
      )),
    );
  }

  Widget _createTestItemView(Test test) {
    return Row(children: <Widget>[
      Expanded(flex: 5, child: Text(test.description)),
      Expanded(
          flex: 1,
          child:
              ElevatedButton(child: Text("Run"), onPressed: () => test.run()))
    ]);
  }

  Widget _createLogMessageViewSection(
      TestsPageViewModel vm, BuildContext context) {
    return Expanded(
        child: Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              "Log:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Padding(padding: EdgeInsetsDirectional.only(top: 8.0)),
            ViewModelPropertyWidgetBuilder(
                viewModel: vm,
                propertyName: TestsPageViewModel.hubLogMessagesPropName,
                builder: (context, snapshot) {
                  return ElevatedButton(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Text("Clear"),
                          Chip(
                            avatar: CircleAvatar(
                              backgroundColor: Colors.blue.shade800,
                              child: Text(vm.hubLogMessages.length.toString()),
                            ),
                            label: Text("Messages"),
                          )
                        ],
                      ),
                      onPressed: () => vm.clearLogs());
                }),
            Padding(padding: EdgeInsetsDirectional.only(top: 8.0)),
            Expanded(
              child: ViewModelPropertyWidgetBuilder(
                  viewModel: vm,
                  propertyName: TestsPageViewModel.hubLogMessagesPropName,
                  builder: (context, snapshot) {
                    return new ListView.builder(
                        itemCount: vm.hubLogMessages.length,
                        itemBuilder: (BuildContext ctx, int index) =>
                            _createLogMessageItemView(
                                vm.hubLogMessages[index]));
                  }),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _createLogMessageItemView(LogRecord item) {
    final at = item.time.toLocal();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
                flex: 3,
                child: Text(
                    "${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}.${at.millisecond.toString().padLeft(3, '0')}")),
            Expanded(flex: 8, child: Text(item.message))
          ],
        ),
      ),
    );
  }
}
