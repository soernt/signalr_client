abstract class IRetryPolicy {
  int nextRetryDelayInMilliseconds(RetryContext retryContext);
}

class RetryContext {
  final int elapsedMilliseconds;
  final int previousRetryCount;
  final Exception retryReason;

  RetryContext(
      this.elapsedMilliseconds, this.previousRetryCount, this.retryReason);
}
