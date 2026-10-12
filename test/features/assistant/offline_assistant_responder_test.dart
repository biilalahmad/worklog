import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/assistant/data/offline_assistant_responder.dart';

void main() {
  test('answers common WorkLog help without relying on the network', () {
    expect(
      OfflineAssistantResponder.replyTo('How do I add a work entry?'),
      contains('Work Log'),
    );
    expect(
      OfflineAssistantResponder.replyTo('currency kahan change karun?'),
      contains('Select Currency'),
    );
    expect(
      OfflineAssistantResponder.replyTo('hello'),
      contains('internet connection'),
    );
  });

  test('does not answer unrelated messages or intercept normal agent prompts',
      () {
    expect(OfflineAssistantResponder.replyTo('Tell me a joke'), isNull);
    expect(
      OfflineAssistantResponder.replyTo('Add a reminder', onlyIfHelp: true),
      isNull,
    );
  });
}
