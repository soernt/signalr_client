typedef OnAbort = void Function();

/// Represents a signal that can be monitored to determine if a request has been aborted.
abstract class IAbortSignal {
  /// Indicates if the request has been aborted.
  bool get aborted;

  /// Set this to a handler that will be invoked when the request is aborted.
  OnAbort onabort;
}

class AbortController implements IAbortSignal {
  // Properties
  bool _isAborted;

  OnAbort onabort;

  bool get aborted => this._isAborted;

  IAbortSignal get signal => this;

  // Methods

  AbortController() {
    this._isAborted = false;
  }

  void abort() {
    if (!this._isAborted) {
      this._isAborted = true;
      if (this.onabort != null) {
        this.onabort();
      }
    }
  }
}
