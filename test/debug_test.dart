import 'package:test/test.dart';
import 'package:dartchess/dartchess.dart';

void main() {
  test('makeIraSquareSet', () {
    const rep = '''
. 1 1 1 . . . .
. 1 . 1 . . . .
. 1 . . 1 . . .
. 1 . . . 1 . .
. 1 1 1 1 . . .
. 1 . . . 1 . .
. 1 . . . 1 . .
. 1 . . 1 . . .
''';
    final sq = makeIraSquareSet(rep);

    expect(rep, humanReadableIraSquareSet(sq));
    expect(makeIraSquareSet('''
. . . . . . . 1
. . . . . . 1 .
. . . . . 1 . .
. . . . 1 . . .
. . . 1 . . . .
. . 1 . . . . .
. 1 . . . . . .
1 . . . . . . .
'''), IraSquareSet.diagonal);
  });

  test('humanReadableBoard', () {
    expect(humanReadableBoard(Board.standard), '''
r n b q k b n r
p p p p p p p p
. . . . . . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
P P P P P P P P
R N B Q K B N R
''');
  });
}
