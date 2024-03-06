import 'dart:async';
import 'package:meta/meta.dart';
import 'package:quiver/strings.dart';
import 'package:rxdart/rxdart.dart';

class PropertyChangedEvent {
  // Properties

  final Object sender;

  final String propertyName;

// Methods
  const PropertyChangedEvent(this.sender, this.propertyName);
}

typedef void SetValue<TValue>(TValue value);

abstract class ViewModel {
  // Properties

  @protected
  final PublishSubject<PropertyChangedEvent> propertyChanges;

  // Methods

  ViewModel() : propertyChanges = PublishSubject<PropertyChangedEvent>();

  @protected
  bool updateValue<TPropertyType>(
      String propertyName,
      TPropertyType currentValue,
      TPropertyType newValue,
      SetValue<TPropertyType>? setNewValue) {
    assert(setNewValue != null);

    if (currentValue == newValue) {
      return false;
    }
    setNewValue!(newValue);
    notifyPropertyChanged(propertyName);
    return true;
  }

  @protected
  void notifyPropertyChanged(String propertyName) {
    propertyChanges.add(PropertyChangedEvent(this, propertyName));
  }

  Stream<PropertyChangedEvent> whenPropertiesChanged(
      List<String>? propertyNames) {
    assert(propertyNames != null || propertyNames!.length != 0);

    return propertyChanges
        .where((event) =>
            isBlank(event.propertyName) ||
            propertyNames!.indexOf(event.propertyName) != -1)
        .transform(StreamTransformer.fromHandlers(handleData:
            (PropertyChangedEvent value, EventSink<PropertyChangedEvent> sink) {
      sink.add(value);
    }));
  }

  Stream<void> whenPropertiesChangedHint(List<String>? propertyNames) {
    assert(propertyNames != null || propertyNames!.length != 0);

    return propertyChanges
        .where((event) =>
            isBlank(event.propertyName) ||
            propertyNames!.indexOf(event.propertyName) != -1)
        .transform(StreamTransformer.fromHandlers(
            handleData: (PropertyChangedEvent value, EventSink<void> sink) {
      sink.add(null);
    }));
  }

  Stream<PropertyChangedEvent> whenPropertyChanged(String propertyName) {
    return propertyChanges
        .where((event) =>
            isBlank(event.propertyName) || event.propertyName == propertyName)
        .transform(StreamTransformer.fromHandlers(handleData:
            (PropertyChangedEvent value, EventSink<PropertyChangedEvent> sink) {
      sink.add(value);
    }));
  }

  Stream whenPropertyChangedHint(String propertyName) {
    return propertyChanges
        .where((event) =>
            isBlank(event.propertyName) || event.propertyName == propertyName)
        .transform(StreamTransformer.fromHandlers(
            handleData: (PropertyChangedEvent value, EventSink<void> sink) {
      sink.add(null);
    }));
  }

  Future<void> viewInitState() {
    return Future<void>.value();
  }

  Future<void> viewDispose() {
    return Future<void>.value();
  }

  void dispose() {
    propertyChanges.close();
  }
}
