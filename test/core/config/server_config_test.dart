import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/core/config/server_config.dart';

Map<String, Object?> _config({
  List<Object?>? modes,
  List<Object?>? interests,
  Map<String, Object?>? limits,
}) {
  return {
    'modes':
        modes ??
        [
          {
            'value': 'dating',
            'label': 'Dating',
            'primary_action_label': 'Like',
            'super_action_label': 'Super Like',
            'description': 'Meet someone new.',
          },
        ],
    'deck_actions': ['pass', 'like', 'super_like'],
    'interests':
        interests ??
        [
          {
            'id': 'i1',
            'slug': 'coffee',
            'label': 'Coffee',
            'category': 'food',
            'modes': ['foodie'],
          },
        ],
    'prompts': <Object?>[],
    'limits':
        limits ??
        {
          'max_interests': 10,
          'max_prompts': 3,
          'max_photos': 6,
          'bio_max_length': 500,
          'default_page_size': 20,
          'max_page_size': 100,
        },
  };
}

void main() {
  test('reads the modes, interests and limits the server publishes', () {
    final config = ServerConfig.fromJson(_config());

    expect(config.modes.single.value, 'dating');
    expect(config.modes.single.label, 'Dating');
    expect(config.modes.single.description, 'Meet someone new.');
    expect(config.interests.single.slug, 'coffee');
    expect(config.interests.single.category, 'food');
    expect(config.limits.maxInterests, 10);
    expect(config.limits.maxPhotos, 6);
    expect(config.limits.bioMaxLength, 500);
  });

  test('reads the prompts and the answers each profile detail accepts', () {
    final config = ServerConfig.fromJson({
      ..._config(),
      'prompts': [
        {
          'id': 'p1',
          'slug': 'perfect_weekend',
          'question': 'A perfect weekend looks like…',
          'modes': ['dating'],
        },
        {'slug': '', 'question': 'Broken'},
      ],
      'lifestyle_options': {
        'drinking': ['never', 'socially', 42],
        'education': ['undergraduate', 'prefer_not_to_say'],
        'broken': 'not a list',
      },
    });

    expect(config.prompts.single.slug, 'perfect_weekend');
    expect(config.prompts.single.question, 'A perfect weekend looks like…');
    expect(config.lifestyleOptions, {
      'drinking': ['never', 'socially'],
      'education': ['undergraduate', 'prefer_not_to_say'],
    });
    expect(config.limits.maxPrompts, 3);
  });

  test('assumes the usual prompt limit when the server leaves it out', () {
    final config = ServerConfig.fromJson(
      _config(
        limits: {'max_interests': 10, 'max_photos': 6, 'bio_max_length': 500},
      ),
    );

    expect(config.limits.maxPrompts, ProfileLimits.defaultMaxPrompts);
    expect(config.prompts, isEmpty);
    expect(config.lifestyleOptions, isEmpty);
  });

  test('leaves out a malformed entry rather than failing', () {
    final config = ServerConfig.fromJson(
      _config(
        interests: [
          {'slug': 'coffee', 'label': 'Coffee', 'category': 'food'},
          {'slug': 42, 'label': 'Broken', 'category': 'food'},
          'not an object',
        ],
      ),
    );

    expect(config.interests.map((interest) => interest.slug), ['coffee']);
  });

  test('fails without the lists or with unusable limits', () {
    expect(
      () => ServerConfig.fromJson({'modes': <Object?>[]}),
      throwsFormatException,
    );
    expect(
      () => ServerConfig.fromJson(
        _config(
          limits: {'max_interests': 0, 'max_photos': 6, 'bio_max_length': 500},
        ),
      ),
      throwsFormatException,
    );
  });
}
