import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/modes/domain/user_modes.dart';

Map<String, Object?> _mode(
  String mode, {
  bool enabled = false,
  bool primary = false,
  bool canEnable = true,
}) {
  return {
    'mode': mode,
    'label': mode,
    'is_enabled': enabled,
    'is_primary': primary,
    'requires_verification': !canEnable,
    'can_enable': canEnable,
    'min_age': 18,
    'max_age': 99,
    'radius_metres': 48280,
    'verified_only': false,
  };
}

void main() {
  test('lists the enabled modes with the main mode first', () {
    final modes = UserModes.fromJson({
      'modes': [
        _mode('dating', enabled: true),
        _mode('networking', enabled: true, primary: true),
        _mode('fitness'),
      ],
      'max_simultaneous_modes': 3,
    });

    expect(modes.enabledModes, ['networking', 'dating']);
    expect(modes.primaryMode, 'networking');
    expect(modes.maxEnabled, 3);
  });

  test('reads a limit of -1 as no limit', () {
    final modes = UserModes.fromJson({
      'modes': <Object?>[],
      'max_simultaneous_modes': -1,
    });

    expect(modes.maxEnabled, isNull);
  });

  test('only modes the server allows can be enabled', () {
    final modes = UserModes.fromJson({
      'modes': [_mode('dating'), _mode('cuddle', canEnable: false)],
      'max_simultaneous_modes': 3,
    });

    expect(modes.canEnable('dating'), isTrue);
    expect(modes.canEnable('cuddle'), isFalse);
    expect(modes.canEnable('not_a_mode'), isFalse);
  });

  test('says when verifying is what unlocks a mode', () {
    final modes = UserModes.fromJson({
      'modes': [
        _mode('dating'),
        _mode('cuddle', canEnable: false),
        {..._mode('trading', canEnable: false), 'requires_verification': false},
      ],
      'max_simultaneous_modes': 3,
    });

    expect(modes.needsVerification('cuddle'), isTrue);
    expect(modes.needsVerification('dating'), isFalse);
    // Locked for some other reason.
    expect(modes.needsVerification('trading'), isFalse);
  });
}
