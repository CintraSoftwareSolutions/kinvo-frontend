import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileState {
  const ProfileState({
    required this.name,
    required this.age,
    required this.location,
    required this.jobTitle,
    required this.organization,
    required this.bio,
    required this.interests,
    required this.completion,
    required this.modes,
    required this.interestsCount,
    required this.photos,
    required this.verified,
    required this.premium,
  });

  final String name;
  final int age;
  final String location;
  final String jobTitle;
  final String organization;
  final String bio;
  final List<String> interests;
  final int completion;
  final int modes;
  final int interestsCount;
  final List<String?> photos;
  final bool verified;
  final bool premium;

  ProfileState copyWith({
    String? name,
    int? age,
    String? location,
    String? jobTitle,
    String? organization,
    String? bio,
    List<String>? interests,
    int? completion,
    int? modes,
    int? interestsCount,
    List<String?>? photos,
    bool? verified,
    bool? premium,
  }) {
    return ProfileState(
      name: name ?? this.name,
      age: age ?? this.age,
      location: location ?? this.location,
      jobTitle: jobTitle ?? this.jobTitle,
      organization: organization ?? this.organization,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      completion: completion ?? this.completion,
      modes: modes ?? this.modes,
      interestsCount: interestsCount ?? this.interestsCount,
      photos: photos ?? this.photos,
      verified: verified ?? this.verified,
      premium: premium ?? this.premium,
    );
  }
}

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    return const ProfileState(
      name: 'Alex Johnson',
      age: 28,
      location: 'Brooklyn, New York',
      jobTitle: 'Senior Product Designer',
      organization: 'Kinvo Studio',
      bio:
          'Product designer who loves coffee, hiking, and building meaningful connections.',
      interests: ['Design', 'Coffee', 'Hiking', 'Photography', 'Travel', 'Tech'],
      completion: 86,
      modes: 3,
      interestsCount: 6,
      photos: [null, null, null, null, null, null],
      verified: true,
      premium: true,
    );
  }

  void updateName(String v) => state = state.copyWith(name: v);
  void updateLocation(String v) => state = state.copyWith(location: v);
  void updateJobTitle(String v) => state = state.copyWith(jobTitle: v);
  void updateOrganization(String v) =>
      state = state.copyWith(organization: v);
  void updateBio(String v) => state = state.copyWith(bio: v);
  void setPhoto(int index, String? path) {
    final next = List<String?>.from(state.photos);
    if (index < 0 || index >= next.length) return;
    next[index] = path;
    state = state.copyWith(photos: next);
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
