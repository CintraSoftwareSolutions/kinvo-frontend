import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/units/distance.dart';
import '../../../settings/presentation/controllers/settings_controllers.dart';
import '../../domain/venue.dart';
import '../controllers/plans_controllers.dart';
import '../plan_presentation.dart';

/// Places to meet near the user, to choose one for a plan. Closes with the
/// place chosen.
class VenuesScreen extends ConsumerStatefulWidget {
  const VenuesScreen({super.key});

  @override
  ConsumerState<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends ConsumerState<VenuesScreen> {
  VenueQuery _query = (category: null, savedOnly: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Places',
              subtitle: 'Somewhere to meet near you',
              leading: HeaderBackButton(),
            ),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  _filter(
                    'All',
                    selected: _query.category == null && !_query.savedOnly,
                    query: (category: null, savedOnly: false),
                  ),
                  _filter(
                    'Saved',
                    selected: _query.savedOnly,
                    query: (category: null, savedOnly: true),
                  ),
                  for (final category in VenueCategory.searchable)
                    _filter(
                      category.label,
                      selected: _query.category == category,
                      query: (category: category, savedOnly: false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _VenueList(query: _query)),
          ],
        ),
      ),
    );
  }

  Widget _filter(
    String label, {
    required bool selected,
    required VenueQuery query,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OptionChip(
        label: label,
        selected: selected,
        onTap: () => setState(() => _query = query),
      ),
    );
  }
}

class _VenueList extends ConsumerWidget {
  const _VenueList({required this.query});

  final VenueQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = venueListProvider(query);
    final venues = ref.watch(provider);

    return switch (venues) {
      AsyncValue(value: final venues?) when venues.isEmpty => ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [_Empty(savedOnly: query.savedOnly)],
      ),
      AsyncValue(value: final venues?) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        itemCount: venues.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _VenueTile(
          venue: venues[index],
          onSave: () async {
            final messenger = ScaffoldMessenger.of(context);
            final error = await ref
                .read(provider.notifier)
                .toggleSaved(venues[index]);
            if (error != null) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(error)));
            }
          },
        ),
      ),
      AsyncValue(:final error?) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              children: [
                const Text(
                  "Places didn't load",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error is ApiException
                      ? error.message
                      : 'Something went wrong. Please try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryActionButton(
                  label: 'Try again',
                  onPressed: () => ref.invalidate(provider),
                ),
              ],
            ),
          ),
        ],
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _VenueTile extends ConsumerWidget {
  const _VenueTile({required this.venue, required this.onSave});

  final Venue venue;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = [
      venue.category.label,
      ?distanceAway(venue.distanceMetres, ref.watch(distanceUnitProvider)),
      if (venue.rating case final rating?) '★ ${rating.toStringAsFixed(1)}',
      if (venue.priceLevel case final level? when level > 0) '£' * level,
    ].join(' · ');

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => context.pop(venue),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.purpleSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  venueIcon(venue.category),
                  size: 22,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Choose ${venue.name}, $details',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (venue.address case final address?)
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onSave,
                tooltip: venue.isSaved ? 'Remove from saved' : 'Save place',
                icon: Icon(
                  venue.isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: venue.isSaved ? AppColors.purple : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.savedOnly});

  final bool savedOnly;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 22),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              savedOnly ? Icons.bookmark_border_rounded : Icons.place_outlined,
              size: 26,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            savedOnly ? 'No saved places' : 'No places near you yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            savedOnly
                ? 'Save places you like, and they wait here for your next plan.'
                : "Kinvo's list of places doesn't reach your area yet. Type "
                      'the place into your plan instead.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (!savedOnly) ...[
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Type a place instead',
              borderRadius: 999,
              onPressed: () => context.pop(),
            ),
          ],
        ],
      ),
    );
  }
}
