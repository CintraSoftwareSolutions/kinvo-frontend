import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinvo/src/features/auth/presentation/controllers/auth_controllers.dart';
import 'package:kinvo/src/features/connections/presentation/controllers/connections_controller.dart';

void main() {
  test('connections are found by id', () {
    final container = ProviderContainer.test();

    expect(container.read(connectionByIdProvider('sarah'))?.name, 'Sarah');
    expect(container.read(connectionByIdProvider('nobody')), isNull);
  });

  test('the OTP form resets once nothing is listening to it', () async {
    final container = ProviderContainer.test();
    final subscription = container.listen(otpControllerProvider, (_, _) {});
    final initialPin = container.read(otpControllerProvider).pin;

    container.read(otpControllerProvider.notifier).updatePin('12');
    expect(container.read(otpControllerProvider).pin, '12');

    subscription.close();
    await container.pump();

    expect(container.read(otpControllerProvider).pin, initialPin);
  });
}
