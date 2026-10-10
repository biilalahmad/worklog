import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/auth/presentation/widgets/security_code_flow.dart';

void main() {
  test('code countdown expires at 180 seconds and resend cooldown is 60 seconds', () {
    var now = DateTime(2026, 10, 3, 12);
    final clock = SecurityCodeClock(now: () => now);
    addTearDown(clock.dispose);

    clock.start();
    expect(clock.secondsRemaining, 180);
    expect(clock.resendSeconds, 60);
    expect(clock.active, isTrue);

    now = now.add(const Duration(seconds: 59));
    clock.tick();
    expect(clock.secondsRemaining, 121);
    expect(clock.resendSeconds, 1);

    now = now.add(const Duration(seconds: 1));
    clock.tick();
    expect(clock.secondsRemaining, 120);
    expect(clock.resendSeconds, 0);
    expect(clock.active, isTrue);

    now = now.add(const Duration(seconds: 120));
    clock.tick();
    expect(clock.secondsRemaining, 0);
    expect(clock.active, isFalse);
  });

  test('reset clears deadlines and formats durations as mm:ss', () {
    final clock = SecurityCodeClock(now: () => DateTime(2026, 10, 3));
    addTearDown(clock.dispose);

    clock.start();
    clock.reset();

    expect(clock.active, isFalse);
    expect(clock.secondsRemaining, 0);
    expect(clock.resendSeconds, 0);
    expect(clock.format(180), '03:00');
    expect(clock.format(9), '00:09');
  });
}
