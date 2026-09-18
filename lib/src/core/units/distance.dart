/// How distances are shown: the user's choice in Settings. The API always
/// works in metres.
enum DistanceUnit {
  miles('miles', metresPerUnit: 1609.344),
  kilometres('kilometres', metresPerUnit: 1000);

  const DistanceUnit(this.wireValue, {required this.metresPerUnit});

  /// The value the settings API uses.
  final String wireValue;

  final double metresPerUnit;

  /// The unit for [value] from the API, or `null` for one this app doesn't
  /// know.
  static DistanceUnit? fromWire(String value) {
    for (final unit in values) {
      if (unit.wireValue == value) return unit;
    }
    return null;
  }

  /// Distances the filters' radius slider stops at, in this unit. The server
  /// accepts up to 500 km.
  List<int> get radiusStops => switch (this) {
    miles => const [1, 2, 5, 10, 15, 25, 30, 50, 75, 100, 150, 200, 300],
    kilometres => const [1, 2, 5, 10, 20, 30, 50, 80, 100, 150, 250, 400, 500],
  };

  /// [count] of this unit in metres, as the API takes them.
  int toMetres(int count) => (count * metresPerUnit).round();

  /// [metres] as a whole number of this unit.
  int fromMetres(num metres) => (metres / metresPerUnit).round();

  /// A distance such as "1 mile" or "25 km".
  String label(int count) => switch (this) {
    miles => count == 1 ? '1 mile' : '$count miles',
    kilometres => '$count km',
  };
}

/// How far away someone or something is, for a card: "4 miles away", or
/// `null` when that isn't known.
///
/// Whole units only, and never more precise than "less than a mile": exact
/// distances between people can be used to work out where someone lives.
String? distanceAway(double? metres, DistanceUnit unit) {
  if (metres == null || metres.isNaN || metres < 0) return null;
  final count = unit.fromMetres(metres);
  if (count < 1) {
    return switch (unit) {
      DistanceUnit.miles => 'Less than a mile away',
      DistanceUnit.kilometres => 'Less than 1 km away',
    };
  }
  return '${unit.label(count)} away';
}

/// A radius for the filters: "25 miles" or "40 km".
String radiusLabel(int metres, DistanceUnit unit) {
  return unit.label(unit.fromMetres(metres));
}
