import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/assistant/domain/assistant_contract.dart';

void main() {
  test('assistant metrics only retain allow-listed aggregates', () {
    final safe = AssistantMetrics.sanitize({
      'work': {
        'entriesThisMonth': 4,
        'clientNames': ['Private Client']
      },
      'finance': {
        'incomeThisMonth': 90,
        'currencyCode': 'PKR',
        'transactionDescription': 'private invoice',
      },
      'prompt': 'arbitrary user text',
    });

    expect(safe, {
      'work': {'entriesThisMonth': 4},
      'finance': {'incomeThisMonth': 90, 'currencyCode': 'PKR'},
    });
  });

  group('AssistantReply', () {
    test('accepts a summary and a supported draft action', () {
      final reply = AssistantReply.fromJson({
        'summary': 'Try a short workout today.',
        'actions': [
          {
            'operation': 'create',
            'domain': 'gym',
            'title': 'Full body session',
            'details': 'A simple three-exercise session.',
            'fields': {'sets': 3},
          }
        ],
      });

      expect(reply.summary, 'Try a short workout today.');
      expect(reply.actions.single.domain, 'gym');
      expect(reply.actions.single.fields['sets'], 3);
    });

    test('rejects unsupported actions and domains', () {
      expect(
        () => AssistantReply.fromJson({
          'summary': 'Review.',
          'actions': [
            {
              'operation': 'delete',
              'domain': 'finance',
              'title': 'Delete transaction',
              'details': '',
              'fields': {},
            }
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => AssistantReply.fromJson({
          'summary': 'Review.',
          'actions': [
            {
              'operation': 'create',
              'domain': 'auth',
              'title': 'Reset password',
              'details': '',
              'fields': {},
            }
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects oversized or malformed responses', () {
      expect(
        () => AssistantReply.fromJson({'summary': 'x' * 3001, 'actions': []}),
        throwsFormatException,
      );
      expect(
        () => AssistantReply.fromJson(
            {'summary': 'Valid', 'actions': List.filled(4, {})}),
        throwsFormatException,
      );
    });
  });
}
