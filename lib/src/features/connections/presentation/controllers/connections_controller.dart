import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/connection.dart';

final connectionFilterProvider =
    StateProvider<ConnectionFilter>((_) => ConnectionFilter.matches);

final connectionsProvider = Provider<List<Connection>>((ref) {
  final filter = ref.watch(connectionFilterProvider);
  switch (filter) {
    case ConnectionFilter.matches:
      return SampleConnections.matches;
    case ConnectionFilter.requests:
      return const [];
    case ConnectionFilter.archived:
      return const [];
  }
});
