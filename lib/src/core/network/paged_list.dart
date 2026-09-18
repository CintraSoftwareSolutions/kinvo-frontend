import 'package:flutter/foundation.dart';

/// A list that loads a page at a time.
@immutable
final class PagedList<T> {
  const PagedList({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  PagedList<T> copyWith({
    List<T>? items,
    ValueGetter<String?>? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return PagedList(
      items: items ?? this.items,
      nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}
