import 'package:test/test.dart';
import 'package:dartchess/dartchess.dart';

void main() async {
  group('Standard chess', () {
    test('initial position', () {
      const pos = Iratus.initial;
      expect(perft(pos, 0), 1);
      expect(perft(pos, 1), 20);
      expect(perft(pos, 2), 400);
      expect(perft(pos, 3), 8902);
      expect(perft(pos, 4), 197281);
    });
  });
}
