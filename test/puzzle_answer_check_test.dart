import 'package:flutter_test/flutter_test.dart';
import 'package:mysterylane/application/services/puzzle_challenge_service.dart';

void main() {
  final service = PuzzleChallengeService();

  test('typed puzzle answers ignore harmless formatting differences', () {
    expect(
      service.checkAnswer(
        userAnswer: 'Sultan Abdul-Samad',
        correctAnswer: 'Sultan Abdul Samad',
      ),
      isTrue,
    );
    expect(
      service.checkAnswer(
        userAnswer: '  Kuala Lumpur! ',
        correctAnswer: 'kuala-lumpur',
      ),
      isTrue,
    );
  });

  test('typed puzzle answers still reject a different answer', () {
    expect(
      service.checkAnswer(
        userAnswer: 'Merdeka Square',
        correctAnswer: 'KLCC Park',
      ),
      isFalse,
    );
    expect(
      service.checkAnswer(userAnswer: '---', correctAnswer: 'KLCC Park'),
      isFalse,
    );
  });
}
