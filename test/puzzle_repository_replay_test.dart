import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mysterylane/data/repositories/puzzle_repository.dart';

Map<String, dynamic> question(int i, {bool general = false}) => {
  'puzzle_id': '${general ? 'g' : 'd'}$i',
  'destination_id': general ? null : 'drawn-destination',
  'puzzle_type': 'Multiple Choice Question',
  'category': general ? 'Malaysia General Knowledge' : 'museum',
  'question_text': 'What is ${general ? 'Malaysia fact' : 'exhibit'} $i?',
  'correct_answer': 'A',
  'option_a': 'A',
  'option_b': 'B',
  'option_c': 'C',
  'option_d': 'D',
  'is_active': true,
};

void main() {
  test(
    'history from another destination does not hide a new destination bank',
    () async {
      var generalBankRequested = false;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object data;
          if (request.url.path.endsWith('/puzzle_questions')) {
            if (request.url.queryParameters['destination_id'] == 'is.null') {
              generalBankRequested = true;
              data = List.generate(100, (i) => question(i, general: true));
            } else {
              data = List.generate(20, question);
            }
          } else if (request.url.path.endsWith('/puzzle_attempts')) {
            data = [
              {
                'attempt_id': 'other-place-round',
                'completed_at': '2026-09-05T00:00:00Z',
              },
            ];
          } else if (request.url.path.endsWith('/puzzle_attempt_answers')) {
            data = List.generate(
              10,
              (i) => {
                'attempt_id': 'other-place-round',
                'puzzle_id': 'other-destination-$i',
                'puzzle_questions': {
                  // Deliberately identical wording to the new destination.
                  'question_text': question(i)['question_text'],
                  'destination_id': 'another-destination',
                },
              },
            );
          } else {
            fail('Unexpected endpoint: ${request.url}');
          }
          return http.Response(
            jsonEncode(data),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);

      final round = await PuzzleRepository(supabase: client)
          .getRandomQuestions(
            userId: 'player',
            destinationId: 'drawn-destination',
            puzzleType: 'Multiple Choice Question',
          );

      expect(round, hasLength(10));
      expect(round.every((q) => !q.isMalaysiaGeneral), true);
      expect(round.map((q) => q.id).toSet(), hasLength(10));
      expect(generalBankRequested, false);
    },
  );

  test('history is paginated and old answers remain seen', () async {
    final attempts = List.generate(
      501,
      (i) => {'attempt_id': 'a$i', 'completed_at': '2026-09-05T00:00:00Z'},
    );
    var pages = 0;
    var answerBatches = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object data;
        if (request.url.path.endsWith('/puzzle_questions')) {
          final general =
              request.url.queryParameters['destination_id'] == 'is.null';
          data = List.generate(
            general ? 100 : 10,
            (i) => question(i, general: general),
          );
        } else if (request.url.path.endsWith('/puzzle_attempts')) {
          pages++;
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          data = attempts.skip(offset).take(500).toList();
        } else {
          expect(request.url.path, endsWith('/puzzle_attempt_answers'));
          answerBatches++;
          data = request.url.queryParameters['attempt_id']!.contains('a500')
              ? [
                  {
                    'attempt_id': 'a500',
                    'puzzle_id': 'd0',
                    'puzzle_questions': {
                      'question_text': question(0)['question_text'],
                      'destination_id': 'drawn-destination',
                    },
                  },
                ]
              : [];
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final round = await PuzzleRepository(supabase: client).getRandomQuestions(
      userId: 'player',
      destinationId: 'drawn-destination',
      puzzleType: 'Multiple Choice Question',
    );
    expect(pages, 2);
    expect(answerBatches, 11);
    expect(round.length, 10);
    expect(round.any((q) => q.id == 'd0'), false);
    expect(round.where((q) => q.isMalaysiaGeneral).length, 1);
  });
  for (final size in [0, 6, 10, 15, 77]) {
    for (final replay in [false, true]) {
      test('database MCQ: bank $size, replay $replay, no generation', () async {
        final requests = <Uri>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request.url);
            expect(request.method, 'GET');
            expect(request.url.path, isNot(contains('/functions/')));
            Object data;
            if (request.url.path.endsWith('/puzzle_questions')) {
              final filter = request.url.queryParameters['destination_id'];
              expect(
                request.url.queryParameters['puzzle_type'],
                'eq.Multiple Choice Question',
              );
              expect(request.url.queryParameters['is_active'], 'eq.true');
              if (filter == 'is.null') {
                expect(
                  request.url.queryParameters['category'],
                  'eq.Malaysia General Knowledge',
                );
                data = List.generate(100, (i) => question(i, general: true));
              } else {
                expect(filter, 'eq.drawn-destination');
                data = List.generate(size, question);
              }
            } else if (request.url.path.endsWith('/puzzle_attempts')) {
              expect(request.url.queryParameters['user_id'], 'eq.player');
              data = replay
                  ? [
                      {
                        'attempt_id': 'previous',
                        'completed_at': '2026-09-05T00:00:00Z',
                      },
                    ]
                  : [];
            } else if (request.url.path.endsWith('/puzzle_attempt_answers')) {
              data = List.generate(
                size < 10 ? size : 10,
                (i) => {
                  'attempt_id': 'previous',
                  'puzzle_id': 'd$i',
                  'puzzle_questions': {
                    'question_text': question(i)['question_text'],
                    'destination_id': 'drawn-destination',
                  },
                },
              );
            } else {
              fail('Unexpected endpoint: ${request.url}');
            }
            return http.Response(
              jsonEncode(data),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final round = await PuzzleRepository(supabase: client)
            .getRandomQuestions(
              userId: 'player',
              destinationId: 'drawn-destination',
              puzzleType: 'Multiple Choice Question',
            );
        expect(round.length, 10);
        expect(round.map((q) => q.id).toSet().length, 10);
        final unseen = replay ? (size > 10 ? size - 10 : 0) : size;
        expect(
          round.where((q) => !q.isMalaysiaGeneral).length,
          unseen > 10 ? 10 : unseen,
        );
        if (replay) {
          expect(
            round.where(
              (q) =>
                  int.tryParse(q.id.substring(1))! < 10 && !q.isMalaysiaGeneral,
            ),
            isEmpty,
          );
        }
        expect(requests.any((url) => url.path.contains('/functions/')), false);
      });
    }
  }
}
