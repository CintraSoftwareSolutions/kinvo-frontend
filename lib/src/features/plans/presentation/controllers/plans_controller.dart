import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/plan.dart';

class PlanComposerState {
  const PlanComposerState({
    required this.connection,
    required this.activity,
    required this.venue,
    required this.dateTime,
  });

  final String connection;
  final String activity;
  final String venue;
  final String dateTime;

  PlanComposerState copyWith({
    String? connection,
    String? activity,
    String? venue,
    String? dateTime,
  }) {
    return PlanComposerState(
      connection: connection ?? this.connection,
      activity: activity ?? this.activity,
      venue: venue ?? this.venue,
      dateTime: dateTime ?? this.dateTime,
    );
  }
}

class PlanComposerController extends Notifier<PlanComposerState> {
  @override
  PlanComposerState build() {
    return const PlanComposerState(
      connection: 'Sarah',
      activity: 'Coffee & walk',
      venue: 'Blue Bottle Coffee',
      dateTime: 'Saturday | 2:00 PM',
    );
  }

  void updateConnection(String v) => state = state.copyWith(connection: v);
  void updateActivity(String v) => state = state.copyWith(activity: v);
  void updateVenue(String v) => state = state.copyWith(venue: v);
  void updateDateTime(String v) => state = state.copyWith(dateTime: v);
}

final planComposerControllerProvider =
    NotifierProvider<PlanComposerController, PlanComposerState>(
  PlanComposerController.new,
);

class PlansController extends Notifier<List<Plan>> {
  @override
  List<Plan> build() => List.of(SamplePlans.all);

  void addFromComposer(PlanComposerState composer) {
    state = [
      Plan(
        id: 'p${state.length + 1}',
        title: composer.activity,
        venue: composer.venue,
        dateTime: composer.dateTime,
        status: PlanStatus.upcoming,
        attendeeAvatar: state.first.attendeeAvatar,
        attendeeName: composer.connection,
        modeColor: state.first.modeColor,
      ),
      ...state,
    ];
  }
}

final plansControllerProvider =
    NotifierProvider<PlansController, List<Plan>>(PlansController.new);
