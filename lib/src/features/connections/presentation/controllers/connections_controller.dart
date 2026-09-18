import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/connection.dart';

/// The sample conversation with the given id, or `null` when there's none.
///
/// Only the demo reaches the conversation screens, which run on sample data
/// until chat is connected to the server.
final connectionByIdProvider = Provider.family<Connection?, String>((ref, id) {
  for (final connection in SampleConnections.matches) {
    if (connection.id == id) return connection;
  }
  return null;
});
