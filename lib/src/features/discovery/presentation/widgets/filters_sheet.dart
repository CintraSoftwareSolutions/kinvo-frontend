import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../modes/domain/mode_filters.dart';
import '../../../settings/presentation/controllers/settings_controllers.dart';
import '../../domain/discovery_mode.dart';
import '../controllers/discovery_actions.dart';

/// Lets the user change who [mode]'s deck is built from.
Future<void> showFiltersSheet(BuildContext context, DiscoveryMode mode) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FiltersSheet(mode: mode),
  );
}

class FiltersSheet extends ConsumerWidget {
  const FiltersSheet({required this.mode, super.key});

  /// The filters a mode starts with on the server.
  static const defaults = ModeFilters(
    minAge: ModeFilters.youngestAge,
    maxAge: ModeFilters.oldestAge,
    radiusMetres: 48280,
    verifiedOnly: false,
  );

  final DiscoveryMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = filtersFormProvider((mode.value, mode.filters));
    final form = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final draft = form.draft;
    final unit = ref.watch(distanceUnitProvider);
    final stops = unit.radiusStops;
    final stop = _nearestStop(stops, unit.fromMetres(draft.radiusMetres));
    String within(int count) => 'Within ${unit.label(count)}';

    Future<void> save() async {
      if (await controller.save() && context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mode.label} filters',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Who you see in this mode. Your other modes keep '
                        'their own filters.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: 'Reset filters',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: form.isSaving
                        ? null
                        : () {
                            controller
                              ..setRadiusMetres(defaults.radiusMetres)
                              ..setAgeRange(defaults.minAge, defaults.maxAge)
                              ..setVerifiedOnly(defaults.verifiedOnly);
                          },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Distance',
              value: within(stop),
              child: Slider(
                value: stops.indexOf(stop).toDouble(),
                max: (stops.length - 1).toDouble(),
                divisions: stops.length - 1,
                activeColor: AppColors.purple,
                label: unit.label(stop),
                semanticFormatterCallback: (value) =>
                    within(stops[value.round()]),
                onChanged: form.isSaving
                    ? null
                    : (value) => controller.setRadiusMetres(
                        unit.toMetres(stops[value.round()]),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Age',
              value: '${draft.minAge} to ${draft.maxAge}',
              child: RangeSlider(
                values: RangeValues(
                  draft.minAge.toDouble(),
                  draft.maxAge.toDouble(),
                ),
                min: ModeFilters.youngestAge.toDouble(),
                max: ModeFilters.oldestAge.toDouble(),
                divisions: ModeFilters.oldestAge - ModeFilters.youngestAge,
                activeColor: AppColors.purple,
                labels: RangeLabels('${draft.minAge}', '${draft.maxAge}'),
                onChanged: form.isSaving
                    ? null
                    : (values) => controller.setAgeRange(
                        values.start.round(),
                        values.end.round(),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _ToggleCard(
              title: 'Verified people only',
              description: 'Only show people who have confirmed who they are.',
              selected: draft.verifiedOnly,
              onTap: form.isSaving
                  ? null
                  : () => controller.setVerifiedOnly(!draft.verifiedOnly),
            ),
            if (form.error case final message?) ...[
              const SizedBox(height: 14),
              FormErrorBanner(message: message),
            ],
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: 'Save filters',
              loading: form.isSaving,
              onPressed: save,
            ),
          ],
        ),
      ),
    );
  }

  /// The stop in [stops] closest to [count], so a radius saved in the other
  /// unit, or on another device, still lands on the slider.
  static int _nearestStop(List<int> stops, int count) {
    var nearest = stops.first;
    for (final stop in stops) {
      if ((stop - count).abs() < (nearest - count).abs()) nearest = stop;
    }
    return nearest;
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.value,
    required this.child,
  });

  final String title;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: selected,
      enabled: onTap != null,
      label: title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purpleChip.withValues(alpha: 0.5)
                : AppColors.surfaceSoft.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.purple : AppColors.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: selected ? AppColors.purple : AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
