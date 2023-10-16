import 'package:dartiratus/dartiratus.dart';
import 'package:test/test.dart';

void main() {
  group('Move', () {
    test('fromUci', () {
      expect(Move.fromUci('a1a2'), const NormalMove(from: 0, to: 8));
      expect(Move.fromUci('h7h8q'),
          const NormalMove(from: 55, to: 63, promotion: Role.queen));
    });

    test('uci', () {
      expect(const NormalMove(from: 2, to: 3).uci, 'c1d1');
      expect(const NormalMove(from: 0, to: 0, promotion: Role.knight).uci,
          'a1a1n');
    });
  });
}
