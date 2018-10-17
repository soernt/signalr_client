import 'package:client/utils/viewModel/viewModel.dart';
import 'package:flutter/widgets.dart';

/// Ruft die 'builder' Funktion auf sobald eine 'PropertyChanged' Nachricht für den übergebenen PropertyNamen eintrifft.
/// Verwendung:
///
///  Widget build(BuildContext context) {
///    final vm = SplashPageViewModelProvider.of(context); // Den Model-Provider nachdem ViewModel berfragen
///    ...
///
///    // Abhängig von der ViewModel-Eigenschaft:
///    return ViewModelPropertyWidgetBuilder<String>(  
///              viewModel: vm,
///              propertyName: "statusText", // PropertyName
///              builder: (context, snapshot) { // Die Daten des Snapshots werden ignoriert
///                return Text(vm.statusText);  // und die vom ViewModel verwendet
///              }),
///}
class ViewModelPropertyWidgetBuilder<TPropertyType> extends StreamBuilder<PropertyChangedEvent> {
  // Properties

  // Methods

  ViewModelPropertyWidgetBuilder({Key key, @required ViewModel viewModel, @required String propertyName, @required AsyncWidgetBuilder<PropertyChangedEvent> builder})
      : super(key: key, builder: builder, stream: viewModel.whenPropertyChanged<TPropertyType>(propertyName));
}
