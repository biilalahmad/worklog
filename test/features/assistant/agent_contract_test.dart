import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/assistant/domain/agent_contract.dart';

void main() {
  group('AssistantAgentAction', () {
    test('accepts a complete create action with model fields', () {
      final reply = AssistantAgentReply.fromJson({
        'message': 'Please review this entry.',
        'action': {
          'name': 'create_work_entry',
          'status': 'ready',
          'fields': {
            'taskName': 'Video edit',
            'clientName': 'Acme',
            'date': '2026-10-12',
            'hoursWorked': 3,
          },
          'missing': [],
          'next_question': '',
          'quick_replies': [],
        },
      });

      expect(reply.action?.status, AssistantActionStatus.ready);
      expect(reply.action?.fields['hoursWorked'], 3);
    });

    test('rejects ready actions missing required data', () {
      expect(
        () => AssistantAgentReply.fromJson({
          'message': 'Review this.',
          'action': {
            'name': 'create_work_entry',
            'status': 'ready',
            'fields': {'taskName': 'Video edit'},
            'missing': [],
            'next_question': '',
            'quick_replies': [],
          },
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown or wrongly typed fields', () {
      for (final fields in [
        {
          'taskName': 'Video',
          'clientName': 'Acme',
          'date': '2026-10-12',
          'databaseId': 'guess'
        },
        {'taskName': 'Video', 'clientName': 42, 'date': '2026-10-12'},
      ]) {
        expect(
          () => AssistantAgentReply.fromJson({
            'message': 'Review.',
            'action': {
              'name': 'create_work_entry',
              'status': 'ready',
              'fields': fields,
              'missing': [],
              'next_question': '',
              'quick_replies': [],
            },
          }),
          throwsFormatException,
        );
      }
    });
  });

  test('confirmation gate accepts only an explicit yes in confirming state',
      () {
    expect(AssistantConfirmationGate.isYes('haan'), isTrue);
    expect(AssistantConfirmationGate.isNo('rehne do'), isTrue);
    expect(
        AssistantConfirmationGate.mayExecute(
            AssistantChatPhase.confirming, true),
        isTrue);
    expect(
        AssistantConfirmationGate.mayExecute(
            AssistantChatPhase.collecting, true),
        isFalse);
    expect(
        AssistantConfirmationGate.mayExecute(
            AssistantChatPhase.confirming, false),
        isFalse);
  });

  test('financial collection requires source and matching app-specific field',
      () {
    final incomeMissing = AssistantActionRegistry.missing(
      AssistantActionName.addFinancial,
      {
        'type': 'income',
        'amount': 150,
        'currency': 'USD',
        'date': '2026-10-12',
      },
    );
    expect(incomeMissing, containsAll(['clientName', 'method']));

    final expenseMissing = AssistantActionRegistry.missing(
      AssistantActionName.addFinancial,
      {
        'type': 'expense',
        'amount': 25,
        'currency': 'PKR',
        'date': '2026-10-12',
      },
    );
    expect(expenseMissing, contains('category'));
  });
}
