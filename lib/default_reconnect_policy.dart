import 'iretry_policy.dart';

class DefaultRetryPolicy implements IRetryPolicy {
  List<int> _retryDelays;

  static const List<int> DEFAULT_RETRY_DELAYS_IN_MILLISECONDS = [0, 2000, 10000, 30000, null];

  DefaultRetryPolicy({List<int> retryDelays}) {
    _retryDelays = retryDelays != null ? [...retryDelays, null] : DEFAULT_RETRY_DELAYS_IN_MILLISECONDS;
  }

  @override
  int nextRetryDelayInMilliseconds(RetryContext retryContext) {
    return _retryDelays[retryContext.previousRetryCount];
  }
}
