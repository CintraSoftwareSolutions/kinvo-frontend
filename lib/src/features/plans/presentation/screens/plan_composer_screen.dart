import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../matches/data/matches_repository.dart';
import '../../../matches/domain/match_summary.dart';
import '../../../matches/presentation/controllers/matches_controllers.dart';
import '../../../modes/presentation/mode_presentation.dart';
import '../../../profile/domain/user_summary.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
import '../../data/plans_repository.dart';
import '../../domain/plan.dart';
import '../../domain/venue.dart';
import '../controllers/plans_controllers.dart';
import '../plan_presentation.dart';

/// The match a new plan was started from, such as its chat.
final _startedFromProvider = FutureProvider.autoDispose
    .family<MatchSummary, String>((ref, matchId) {
      return ref.watch(matchesRepositoryProvider).fetchMatch(matchId);
    });

/// Makes a new plan, or changes one of the user's own: with whom, where,
/// when, for how long, and a note.
class PlanComposerScreen extends ConsumerWidget {
  const PlanComposerScreen({this.matchId, this.planId, super.key});

  /// The match a new plan is with, when it was started from one.
  final String? matchId;

  /// The plan to change. `null` for a new one.
  final String? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planId = this.planId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: planId == null ? 'New plan' : 'Edit plan',
              subtitle: planId == null
                  ? 'Suggest a time and place to meet'
                  : null,
              leading: const HeaderBackButton(),
            ),
            Expanded(
              child: planId == null
                  ? _ComposerForm(matchId: matchId)
                  : switch (ref.watch(planProvider(planId))) {
                      // Keyed by the plan, so the form starts from it once and
                      // then keeps what the user typed.
                      AsyncValue(value: final plan?) => _ComposerForm(
                        key: ValueKey(plan.id),
                        existing: plan,
                      ),
                      AsyncValue(:final error?) => _Unavailable(
                        message: error is ApiException
                            ? error.message
                            : 'Something went wrong. Please try again.',
                      ),
                      _ => const Center(child: CircularProgressIndicator()),
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Who a plan is with.
typedef _Who = ({String matchId, UserSummary user, String mode});

class _ComposerForm extends ConsumerStatefulWidget {
  const _ComposerForm({this.matchId, this.existing, super.key});

  final String? matchId;
  final Plan? existing;

  @override
  ConsumerState<_ComposerForm> createState() => _ComposerFormState();
}

class _ComposerFormState extends ConsumerState<_ComposerForm> {
  /// Durations offered, in minutes.
  static const _durations = [30, 60, 90, 120, 180];

  _Who? _chosen;
  PlanVenue? _venue;
  bool _typingPlace = false;
  String _place = '';
  String _address = '';
  DateTime? _day;
  TimeOfDay? _time;
  int? _duration;
  String _notes = '';

  bool _saving = false;
  bool _sending = false;

  /// Whether the user has tried to save, after which problems show.
  bool _tried = false;

  /// The server's messages, by section.
  Map<String, String> _refused = const {};
  String? _error;

  Plan? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    if (_existing case final plan?) {
      _chosen = (matchId: plan.matchId, user: plan.user, mode: plan.mode);
      _venue = plan.venue;
      _typingPlace = plan.venue == null;
      _place = plan.customLocation ?? '';
      _address = plan.customAddress ?? '';
      if (plan.scheduledAt?.toLocal() case final at?) {
        _day = DateUtils.dateOnly(at);
        _time = TimeOfDay.fromDateTime(at);
      }
      _duration = plan.durationMinutes;
      _notes = plan.notes ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    final who = _who();
    final problems = _tried
        ? _problems(sending: _sending)
        : const <String, String>{};
    String? problem(String section) => problems[section] ?? _refused[section];

    if (existing != null && !existing.canEdit) {
      return const _Unavailable(
        message:
            'This plan has been answered or called off, so it '
            "can't be changed any more.",
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
      children: [
        const _SectionTitle('WITH'),
        if (existing != null || widget.matchId != null)
          _WhoCard(who: who, loading: who == null)
        else
          _MatchPicker(
            chosen: _chosen?.matchId,
            onChosen: (match) => setState(() {
              _chosen = (matchId: match.id, user: match.user, mode: match.mode);
            }),
          ),
        if (problem('who') case final message?) _ErrorText(message),
        const SizedBox(height: 18),
        const _SectionTitle('WHERE'),
        ..._placeSection(who, problem('place'), problem('address')),
        const SizedBox(height: 18),
        const _SectionTitle('WHEN'),
        Row(
          children: [
            Expanded(
              child: AppPickerCard(
                label: 'Day',
                placeholder: 'Choose a day',
                icon: Icons.calendar_today_outlined,
                value: _day == null
                    ? null
                    : MaterialLocalizations.of(context).formatMediumDate(_day!),
                onTap: _pickDay,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppPickerCard(
                label: 'Time',
                placeholder: 'Choose a time',
                icon: Icons.schedule_rounded,
                value: _time == null
                    ? null
                    : MaterialLocalizations.of(context).formatTimeOfDay(_time!),
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        if (problem('when') case final message?) _ErrorText(message),
        const SizedBox(height: 18),
        const _SectionTitle('HOW LONG'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in _durations)
              OptionChip(
                label: durationLabel(minutes),
                selected: _duration == minutes,
                onTap: () => setState(() => _duration = minutes),
              ),
            // The API can't take a length away once a plan has one.
            if (existing?.durationMinutes == null)
              OptionChip(
                label: 'Not sure',
                selected: _duration == null,
                onTap: () => setState(() => _duration = null),
              ),
          ],
        ),
        if (problem('duration') case final message?) _ErrorText(message),
        const SizedBox(height: 18),
        const _SectionTitle('NOTE'),
        AppInputCard(
          label: 'For them to know (optional)',
          hintText: 'Meet by the entrance?',
          value: _notes,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          errorText: problem('notes'),
          onChanged: (value) => _notes = value,
        ),
        const SizedBox(height: 22),
        if (_error case final message?) ...[
          FormErrorBanner(message: message),
          const SizedBox(height: 12),
        ],
        ..._buttons(existing, who),
      ],
    );
  }

  /// The place section: a place from Kinvo's list, or one typed in.
  List<Widget> _placeSection(
    _Who? who,
    String? placeProblem,
    String? addressProblem,
  ) {
    final venue = _venue;
    if (venue != null) {
      return [
        _ChosenVenue(
          venue: venue,
          onChange: _pickVenue,
          onClear: () => setState(() => _venue = null),
        ),
        if (placeProblem != null) _ErrorText(placeProblem),
      ];
    }

    if (_typingPlace) {
      return [
        AppInputCard(
          label: 'Place',
          hintText: 'The ramen bar on King Street',
          value: _place,
          textCapitalization: TextCapitalization.sentences,
          errorText: placeProblem,
          onChanged: (value) => _place = value,
        ),
        const SizedBox(height: 10),
        AppInputCard(
          label: 'Address (optional)',
          hintText: 'So they can find it',
          value: _address,
          textCapitalization: TextCapitalization.words,
          errorText: addressProblem,
          onChanged: (value) => _address = value,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _typingPlace = false),
            child: const Text('Choose from places instead'),
          ),
        ),
      ];
    }

    return [
      if (who != null) _Suggestions(matchId: who.matchId, onChosen: _useVenue),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickVenue,
              style: _outlined,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Find a place'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _typingPlace = true),
              style: _outlined,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Type a place'),
            ),
          ),
        ],
      ),
      if (placeProblem != null) _ErrorText(placeProblem),
    ];
  }

  List<Widget> _buttons(Plan? existing, _Who? who) {
    final name = who?.user.displayName ?? 'them';
    if (existing?.status == PlanStatus.proposed) {
      return [
        PrimaryActionButton(
          label: 'Save changes',
          loading: _saving,
          borderRadius: 999,
          onPressed: _saving ? null : () => _submit(send: false),
        ),
        const SizedBox(height: 8),
        Text(
          '$name will be told about the change.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ];
    }
    return [
      PrimaryActionButton(
        label: 'Send plan',
        loading: _saving && _sending,
        borderRadius: 999,
        onPressed: _saving ? null : () => _submit(send: true),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: _saving ? null : () => _submit(send: false),
        style: _outlined,
        child: Text(existing == null ? 'Save as draft' : 'Save draft'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Only you can see a draft until you send it.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ];
  }

  /// Who the plan is with: chosen here, or the match it was started from.
  _Who? _who() {
    if (_chosen case final chosen?) return chosen;
    final matchId = widget.matchId;
    if (matchId == null) return null;
    final match = ref.watch(_startedFromProvider(matchId)).value;
    if (match == null) return null;
    return (matchId: match.id, user: match.user, mode: match.mode);
  }

  DateTime? get _scheduledAt {
    final (day, time) = (_day, _time);
    if (day == null || time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  /// What stops the plan being saved, or sent when [sending], by section.
  Map<String, String> _problems({required bool sending}) {
    final problems = <String, String>{};
    if (_who() == null) problems['who'] = 'Choose who the plan is with.';

    final place = _place.trim();
    if (_venue == null) {
      if (place.isEmpty) {
        problems['place'] = 'Choose a place, or type one.';
      } else if (place.length > 200) {
        problems['place'] = 'Keep the place under 200 characters.';
      }
      if (_address.trim().length > 300) {
        problems['address'] = 'Keep the address under 300 characters.';
      }
    }

    final at = _scheduledAt;
    if (_day == null && _time == null) {
      if (sending) problems['when'] = 'Choose a day and a time to send it.';
    } else if (at == null) {
      problems['when'] = 'Choose both a day and a time.';
    } else if (!at.isAfter(ref.read(clockProvider)())) {
      problems['when'] = 'Pick a time in the future.';
    }

    if (_notes.trim().length > 1000) {
      problems['notes'] = 'Keep the note under 1,000 characters.';
    }
    return problems;
  }

  Future<void> _submit({required bool send}) async {
    setState(() {
      _tried = true;
      _sending = send;
      _refused = const {};
      _error = null;
    });
    final who = _who();
    if (who == null || _problems(sending: send).isNotEmpty) return;

    final venue = _venue;
    final details = PlanDetails(
      venueId: venue?.id,
      customLocation: venue == null ? _place.trim() : null,
      customAddress: venue == null ? _address.trim() : null,
      scheduledAt: _scheduledAt,
      durationMinutes: _duration,
      notes: _notes.trim(),
    );

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final actions = ref.read(planActionsProvider);
    final existing = _existing;
    final outcome = existing == null
        ? await actions.create(
            matchId: who.matchId,
            details: details,
            send: send,
          )
        : await actions.update(existing, details, send: send);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case PlanSaved(:final plan):
        final name = plan.user.displayName;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(switch (plan.status) {
                PlanStatus.proposed when existing?.status == plan.status =>
                  'Changes saved. $name has been told.',
                PlanStatus.proposed => 'Sent to $name.',
                _ => 'Saved as a draft.',
              }),
            ),
          );
        // Where the plan now lists, for when the user goes back to Plans.
        ref
            .read(plansTabProvider.notifier)
            .select(
              plan.status == PlanStatus.draft
                  ? PlansTab.drafts
                  : PlansTab.pending,
            );
        if (existing != null) {
          router.pop();
        } else {
          unawaited(router.pushReplacement(AppRoutes.plan(plan.id)));
        }
      case PlanRefused(:final message, :final fieldErrors):
        setState(() {
          _refused = {
            for (final MapEntry(:key, :value) in fieldErrors.entries)
              if (value.isNotEmpty) _sectionFor(key): value.first,
          };
          if (_refused.isEmpty) _error = message;
        });
    }
  }

  static String _sectionFor(String field) {
    return switch (field) {
      'venue_id' || 'custom_location' => 'place',
      'custom_address' => 'address',
      'scheduled_at' => 'when',
      'duration_minutes' => 'duration',
      'notes' => 'notes',
      'match_id' => 'who',
      _ => 'place',
    };
  }

  Future<void> _pickDay() async {
    final today = DateUtils.dateOnly(ref.read(clockProvider)());
    final chosen = _day;
    final picked = await showDatePicker(
      context: context,
      initialDate: chosen == null || chosen.isBefore(today)
          ? today.add(const Duration(days: 1))
          : chosen,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Choose a day',
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
      helpText: 'Choose a time',
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _pickVenue() async {
    final venue = await context.push<Venue>(AppRoutes.venues);
    if (venue != null && mounted) _useVenue(venue);
  }

  void _useVenue(Venue venue) {
    setState(() {
      _venue = PlanVenue(
        id: venue.id,
        name: venue.name,
        category: venue.category,
        address: venue.address,
      );
      _typingPlace = false;
    });
  }

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.divider),
    backgroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 13),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.danger),
      ),
    );
  }
}

/// The person a plan is with, when that's already settled.
class _WhoCard extends StatelessWidget {
  const _WhoCard({required this.who, required this.loading});

  final _Who? who;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final who = this.who;
    if (who == null) {
      return const SurfaceCard(
        child: SizedBox(
          height: 44,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return SurfaceCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 44,
              height: 44,
              child: PersonPhoto(
                url: who.user.photoUrl,
                name: who.user.displayName,
                color: modeColors(who.mode).primary,
                initialSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              who.user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The user's current matches to choose from, when the plan isn't started
/// from one.
class _MatchPicker extends ConsumerWidget {
  const _MatchPicker({required this.chosen, required this.onChosen});

  final String? chosen;
  final ValueChanged<MatchSummary> onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = matchesListProvider(false);
    final matches = ref.watch(provider);
    final list = matches.value;

    if (list == null) {
      if (matches.hasError) {
        return SurfaceCard(
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "Your matches didn't load.",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('Try again'),
              ),
            ],
          ),
        );
      }
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Only those still open for messages can be planned with.
    final open = [
      for (final match in list.items)
        if (match.isWritable) match,
    ];
    if (open.isEmpty) {
      return const SurfaceCard(
        child: Text(
          'Plans are made with matches. When you match with someone, you can '
          'suggest a plan here.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 200) {
            ref.read(provider.notifier).loadMore();
          }
          return false;
        },
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: open.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final match = open[index];
            final selected = match.id == chosen;
            return Semantics(
              button: true,
              selected: selected,
              label: match.user.displayName,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChosen(match),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.purple
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: PersonPhoto(
                            url: match.user.photoUrl,
                            name: match.user.displayName,
                            color: modeColors(match.mode).primary,
                            initialSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        match.user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Places suited to the match's mode, one tap to choose.
class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.matchId, required this.onChosen});

  final String matchId;
  final ValueChanged<Venue> onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(venueSuggestionsProvider(matchId)).value;
    if (venues == null || venues.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: Column(
          children: [
            for (final (index, venue) in venues.take(4).indexed) ...[
              if (index > 0)
                const Divider(height: 1, indent: 60, color: AppColors.divider),
              ListTile(
                onTap: () => onChosen(venue),
                leading: Icon(
                  venueIcon(venue.category),
                  color: AppColors.purple,
                ),
                title: Text(
                  venue.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  venue.category.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChosenVenue extends StatelessWidget {
  const _ChosenVenue({
    required this.venue,
    required this.onChange,
    required this.onClear,
  });

  final PlanVenue venue;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final address = venue.address;
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.purpleSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              venueIcon(venue.category),
              size: 20,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                if (address != null)
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
          IconButton(
            onPressed: onClear,
            tooltip: 'Remove place',
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            children: [
              const Text(
                "This plan can't be changed",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryActionButton(
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
