import 'dart:async';

/// Waits for [a] and [b] together, failing with whichever failed first rather
/// than with the [ParallelWaitError] that would hide it — so screens can still
/// say what went wrong. Waiting on both at once also means a failure of either
/// is never left unhandled while the other is awaited.
Future<(A, B)> waitBoth<A, B>(Future<A> a, Future<B> b) async {
  try {
    return await (a, b).wait;
  } on ParallelWaitError<(A?, B?), (AsyncError?, AsyncError?)> catch (error) {
    final (errorA, errorB) = error.errors;
    final first = (errorA ?? errorB)!;
    Error.throwWithStackTrace(first.error, first.stackTrace);
  }
}
