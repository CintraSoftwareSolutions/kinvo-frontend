import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/server_config.dart';
import '../../../../core/config/server_config_providers.dart';
import '../../../../core/forms/form_errors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../controllers/profile_controllers.dart';

/// Choosing the profile's interests from the server's catalogue.
class InterestsEditScreen extends ConsumerStatefulWidget {
  const InterestsEditScreen({super.key});

  @override
  ConsumerState<InterestsEditScreen> createState() =>
      _InterestsEditScreenState();
}

class _InterestsEditScreenState extends ConsumerState<InterestsEditScreen> {
  /// The interests chosen so far, in the order they were picked. `null`
  /// until the profile has loaded.
  List<String>? _selected;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownProfileProvider).value;
    final catalogue = ref.watch(profileCatalogueProvider);
    if (_selected == null && profile != null) {
      if (catalogue.value case final config?) {
        // An interest the catalogue has retired can't be chosen again, and
        // the server would refuse the whole list with it in.
        final offered = {
          for (final interest in config.interests) interest.slug,
        };
        _selected = [
          for (final slug in profile.interestSlugs)
            if (offered.contains(slug)) slug,
        ];
      }
    }
    final selected = _selected;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Your interests',
              subtitle: 'Pick what you like, so people see what you share',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: switch (catalogue) {
                AsyncValue(value: final config?) when selected != null =>
                  _Picker(
                    interests: config.interests,
                    selected: selected,
                    maxInterests: config.limits.maxInterests,
                    enabled: !_saving,
                    onToggle: (slug) => _toggle(slug, config.limits),
                  ),
                AsyncValue(:final error?) => ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  children: [
                    LoadFailedCard(
                      message: saveFailureMessage(error),
                      onRetry: () => ref.invalidate(serverConfigProvider),
                    ),
                  ],
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            if (selected != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error case final error?) ...[
                        FormErrorBanner(message: error),
                        const SizedBox(height: 10),
                      ],
                      PrimaryActionButton(
                        label: 'Save interests',
                        borderRadius: 999,
                        loading: _saving,
                        onPressed: () => _save(selected),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggle(String slug, ProfileLimits limits) {
    final selected = [...?_selected];
    if (selected.contains(slug)) {
      selected.remove(slug);
    } else if (selected.length >= limits.maxInterests) {
      setState(
        () => _error =
            'You can choose up to ${limits.maxInterests} interests. Remove '
            'one to add another.',
      );
      return;
    } else {
      selected.add(slug);
    }
    setState(() {
      _selected = selected;
      _error = null;
    });
  }

  Future<void> _save(List<String> selected) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(ownProfileProvider.notifier).setInterests(selected);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = saveFailureMessage(error, field: 'interests');
      });
    }
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.interests,
    required this.selected,
    required this.maxInterests,
    required this.enabled,
    required this.onToggle,
  });

  final List<InterestOption> interests;
  final List<String> selected;
  final int maxInterests;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            '${selected.length} of $maxInterests chosen',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        for (final (category, options) in groupInterestsByCategory(
          interests,
        )) ...[
          const SizedBox(height: 18),
          SettingsSectionLabel(interestCategoryLabel(category).toUpperCase()),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final interest in options)
                OptionChip(
                  label: interest.label,
                  selected: selected.contains(interest.slug),
                  onTap: enabled ? () => onToggle(interest.slug) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
