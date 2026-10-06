import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/links/external_links.dart';
import '../../../../core/theme/kinvo_colors.dart';
import '../../domain/venue.dart';

/// The credit Geoapify and OpenStreetMap ask for wherever their places are
/// shown: under a list holding any of them, and nowhere else.
class PlacesCredit extends ConsumerWidget {
  const PlacesCredit({required this.venues, super.key});

  final List<Venue> venues;

  static final geoapify = Uri.parse('https://www.geoapify.com/');
  static final openStreetMap = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  /// Whether [venues] holds anything that needs crediting.
  static bool needed(List<Venue> venues) {
    return venues.any((venue) => venue.source == VenueSource.geoapify);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!needed(venues)) return const SizedBox.shrink();

    final links = ref.read(externalLinksProvider);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Credit(
          label: 'Powered by Geoapify',
          onTap: () => unawaited(links.openPage(geoapify)),
        ),
        Text(
          '·',
          style: TextStyle(fontSize: 11.5, color: context.colors.textMuted),
        ),
        _Credit(
          label: '© OpenStreetMap contributors',
          onTap: () => unawaited(links.openPage(openStreetMap)),
        ),
      ],
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: context.colors.textMuted,
              decoration: TextDecoration.underline,
              decorationColor: context.colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
