import 'package:flutter/widgets.dart';
import 'viewModel.dart';

class ViewModelPropertyWidgetBuilder<TPropertyType>
    extends StreamBuilder<PropertyChangedEvent> {
  // Properties

  // Methods

  ViewModelPropertyWidgetBuilder(
      {Key? key,
      ViewModel? viewModel,
      required String propertyName,
      required AsyncWidgetBuilder<PropertyChangedEvent> builder})
      : super(
            key: key,
            builder: builder,
            stream: viewModel?.whenPropertyChanged(propertyName));
}
