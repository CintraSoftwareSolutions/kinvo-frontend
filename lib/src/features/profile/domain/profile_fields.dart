/// The details on a profile that are changed one at a time, with their names
/// in the API.
enum ProfileField {
  displayName('display_name', 'Name'),
  bio('bio', 'Bio'),
  jobTitle('job_title', 'Job title'),
  organisation('organisation', 'Organisation'),
  education('education', 'Education'),
  heightCm('height_cm', 'Height'),
  city('city', 'City'),
  drinking('drinking', 'Drinking'),
  smoking('smoking', 'Smoking'),
  exercise('exercise', 'Exercise'),
  diet('diet', 'Diet'),
  pets('pets', 'Pets'),
  children('children', 'Children');

  const ProfileField(this.apiName, this.label);

  /// The field's name in `PATCH /users/me` and `GET /users/me`.
  final String apiName;

  /// What the field is called on screen.
  final String label;

  /// The lifestyle questions, in the order profiles show them.
  static const lifestyle = [drinking, smoking, exercise, diet, pets, children];

  /// Whether it's answered by picking from the answers `GET /config`
  /// publishes rather than by typing.
  bool get hasOptions => this == education || lifestyle.contains(this);
}

/// An answer to a profile question as words, such as "Socially" for
/// `socially`.
///
/// Values the app has no words for, such as ones the server adds later, are
/// shown as they are, with underscores as spaces.
String profileOptionLabel(ProfileField field, String value) {
  final special = switch ((field, value)) {
    (_, 'prefer_not_to_say') => 'Prefer not to say',
    (ProfileField.education, 'high_school') => 'High school',
    (ProfileField.education, 'undergraduate') => 'Undergraduate degree',
    (ProfileField.education, 'postgraduate') => 'Postgraduate degree',
    (ProfileField.exercise, 'daily') => 'Every day',
    (ProfileField.diet, 'omnivore') => 'Eats everything',
    (ProfileField.pets, 'none') => 'No pets',
    (ProfileField.pets, 'dog') => 'Dog',
    (ProfileField.pets, 'cat') => 'Cat',
    (ProfileField.pets, 'other') => 'Other pets',
    (ProfileField.pets, 'multiple') => 'Several pets',
    (ProfileField.children, 'none') => 'No children',
    (ProfileField.children, 'have_children') => 'Have children',
    (ProfileField.children, 'want_children') => 'Want children',
    (ProfileField.children, 'do_not_want_children') => "Don't want children",
    (ProfileField.children, 'open') => 'Open to children',
    _ => null,
  };
  if (special != null) return special;

  final words = value.replaceAll('_', ' ').trim();
  if (words.isEmpty) return words;
  return words[0].toUpperCase() + words.substring(1);
}

/// A height as "175 cm (5 ft 9 in)", for people who think in either.
String heightLabel(int centimetres) {
  final inches = (centimetres / 2.54).round();
  return '$centimetres cm (${inches ~/ 12} ft ${inches % 12} in)';
}
