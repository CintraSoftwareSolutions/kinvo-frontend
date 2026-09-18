import 'package:flutter/foundation.dart';

/// One page of results from a cursor-paginated list endpoint.
@immutable
final class CursorPage<T> {
  const CursorPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.limit,
  });

  final List<T> items;

  /// Pass this back unchanged to fetch the following page; `null` on the last
  /// page. Its contents are deliberately opaque, so never parse or build one.
  final String? nextCursor;

  final bool hasMore;

  /// The page size the server applied, which may differ from the one requested.
  final int limit;
}
