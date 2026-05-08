import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileSetupControllerProvider =
    NotifierProvider<ProfileSetupController, ProfileSetupState>(
      ProfileSetupController.new,
    );

class ProfileSetupState {
  const ProfileSetupState({
    required this.name,
    required this.location,
    required this.genderIdentity,
    required this.purpose,
    required this.lifestyle,
  });

  final String name;
  final String location;
  final String genderIdentity;
  final Set<String> purpose;
  final Set<String> lifestyle;

  ProfileSetupState copyWith({
    String? name,
    String? location,
    String? genderIdentity,
    Set<String>? purpose,
    Set<String>? lifestyle,
  }) {
    return ProfileSetupState(
      name: name ?? this.name,
      location: location ?? this.location,
      genderIdentity: genderIdentity ?? this.genderIdentity,
      purpose: purpose ?? this.purpose,
      lifestyle: lifestyle ?? this.lifestyle,
    );
  }
}

class ProfileSetupController extends Notifier<ProfileSetupState> {
  @override
  ProfileSetupState build() {
    return const ProfileSetupState(
      name: 'Alex Johnson',
      location: 'Brooklyn, New York',
      genderIdentity: 'Woman',
      purpose: {'Dating', 'Networking'},
      lifestyle: {'Pet friendly', 'Remote worker', 'Weekend traveler'},
    );
  }

  void updateName(String value) => state = state.copyWith(name: value);

  void updateLocation(String value) => state = state.copyWith(location: value);

  void selectGender(String value) {
    state = state.copyWith(genderIdentity: value);
  }

  void togglePurpose(String value) {
    final next = {...state.purpose};
    if (!next.add(value)) {
      next.remove(value);
    }
    state = state.copyWith(purpose: next);
  }

  void toggleLifestyle(String value) {
    final next = {...state.lifestyle};
    if (!next.add(value)) {
      next.remove(value);
    }
    state = state.copyWith(lifestyle: next);
  }
}
