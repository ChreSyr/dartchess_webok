import 'package:dartiratus/dartiratus.dart';
import 'package:test/test.dart';

void main() {
  test('toString', () {
    expect(IraSquareSet.empty.toString(), 'IraSquareSet(0)');
    expect(IraSquareSet.full.toString(), 'IraSquareSet(0xFFFFFFFFFFFFFFFF)');
    expect(IraSquareSet.lightSquares.toString(),
        'IraSquareSet(0x55AA55AA55AA55AA)');
    expect(IraSquareSet.darkSquares.toString(),
        'IraSquareSet(0xAA55AA55AA55AA55)');
    expect(
        IraSquareSet.diagonal.toString(), 'IraSquareSet(0x8040201008040201)');
    expect(IraSquareSet.antidiagonal.toString(),
        'IraSquareSet(0x0102040810204080)');
    expect(IraSquareSet.corners.toString(), 'IraSquareSet(0x8100000000000081)');
    expect(
        IraSquareSet.backranks.toString(), 'IraSquareSet(0xFF000000000000FF)');
    expect(const IraSquareSet(0x0000000000000001).toString(),
        'IraSquareSet(0x0000000000000001)');
    expect(
        const IraSquareSet(0xf).toString(), 'IraSquareSet(0x000000000000000F)');
  });

  test('full set has all', () {
    for (Square square = 0; square < 64; square++) {
      expect(IraSquareSet.full.has(square), true);
    }
  });

  test('size', () {
    IraSquareSet squares = IraSquareSet.empty;
    for (int i = 0; i < 64; i++) {
      expect(squares.size, i);
      squares = squares.withSquare(i);
    }
  });

  test('shr', () {
    const r = IraSquareSet(0xe0a12221e222212);
    expect(r.shr(0), r);
    expect(r.shr(1), const IraSquareSet(0x70509110f111109));
    expect(r.shr(3), const IraSquareSet(0x1c1424443c44442));
    expect(r.shr(48), const IraSquareSet(0xe0a));
    expect(r.shr(62), IraSquareSet.empty);
  });

  test('shl', () {
    const r = IraSquareSet(0xe0a12221e222212);
    expect(r.shl(0), r);
    expect(r.shl(1), const IraSquareSet(0x1c1424443c444424));
    expect(r.shl(3), const IraSquareSet(0x70509110f1111090));
    expect(r.shl(10), const IraSquareSet(0x2848887888884800));
    expect(r.shl(32), const IraSquareSet(0x1e22221200000000));
    expect(r.shl(48), const IraSquareSet(0x2212000000000000));
    expect(r.shl(62), const IraSquareSet(0x8000000000000000));
    expect(r.shl(63), IraSquareSet.empty);
  });

  test('first', () {
    for (Square square = 0; square < 64; square++) {
      expect(IraSquareSet.fromSquare(square).first, square);
    }
    expect(IraSquareSet.full.first, 0);
    expect(IraSquareSet.empty.first, null);
    for (int rank = 0; rank < 8; rank++) {
      expect(IraSquareSet.fromRank(rank).first, rank * 8);
    }
  });

  test('last', () {
    for (Square square = 0; square < 64; square++) {
      expect(IraSquareSet.fromSquare(square).last, square);
    }
    expect(IraSquareSet.full.last, 63);
    expect(IraSquareSet.empty.last, null);
    for (int rank = 0; rank < 8; rank++) {
      expect(IraSquareSet.fromRank(rank).last, rank * 8 + 7);
    }
  });

  test('more that one', () {
    expect(IraSquareSet.empty.moreThanOne, false);
    expect(IraSquareSet.full.moreThanOne, true);
    expect(const IraSquareSet.fromSquare(4).moreThanOne, false);
    expect(const IraSquareSet.fromSquare(4).withSquare(5).moreThanOne, true);
  });

  test('singleSquare', () {
    expect(IraSquareSet.empty.singleSquare, null);
    expect(IraSquareSet.full.singleSquare, null);
    expect(const IraSquareSet.fromSquare(4).singleSquare, 4);
    expect(const IraSquareSet.fromSquare(4).withSquare(5).singleSquare, null);
  });

  test('squares', () {
    expect(IraSquareSet.empty.squares.toList(), List<Square>.empty());
    expect(
        IraSquareSet.full.squares.toList(), [for (int i = 0; i < 64; i++) i]);
    expect(
        IraSquareSet.diagonal.squares, equals([0, 9, 18, 27, 36, 45, 54, 63]));
  });

  test('squaresReversed', () {
    expect(IraSquareSet.empty.squaresReversed.toList(), List<Square>.empty());
    expect(IraSquareSet.full.squaresReversed.toList(),
        [for (int i = 63; i >= 0; i--) i]);
    expect(IraSquareSet.diagonal.squaresReversed,
        equals([63, 54, 45, 36, 27, 18, 9, 0]));
  });

  test('from file', () {
    expect(
        const IraSquareSet.fromFile(0), const IraSquareSet(0x0101010101010101));
    expect(
        const IraSquareSet.fromFile(7), const IraSquareSet(0x8080808080808080));
  });

  test('from rank', () {
    expect(
        const IraSquareSet.fromRank(0), const IraSquareSet(0x00000000000000FF));
    expect(
        const IraSquareSet.fromRank(7), const IraSquareSet(0xFF00000000000000));
  });

  test('from square', () {
    expect(const IraSquareSet.fromSquare(42), makeIraSquareSet('''
. . . . . . . .
. . . . . . . .
. . 1 . . . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
'''));
  });

  test('from squares', () {
    expect(
        IraSquareSet.fromSquares(const [42, 44, 26, 28]), makeIraSquareSet('''
. . . . . . . .
. . . . . . . .
. . 1 . 1 . . .
. . . . . . . .
. . 1 . 1 . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
'''));
  });

  test('with square', () {
    expect(IraSquareSet.center.withSquare(43), makeIraSquareSet('''
. . . . . . . .
. . . . . . . .
. . . 1 . . . .
. . . 1 1 . . .
. . . 1 1 . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
'''));
  });

  test('without square', () {
    expect(IraSquareSet.center.withoutSquare(27), makeIraSquareSet('''
. . . . . . . .
. . . . . . . .
. . . . . . . .
. . . 1 1 . . .
. . . . 1 . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
'''));
  });

  test('toggle square', () {
    expect(IraSquareSet.center.toggleSquare(35).toggleSquare(43),
        makeIraSquareSet('''
. . . . . . . .
. . . . . . . .
. . . 1 . . . .
. . . . 1 . . .
. . . 1 1 . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
'''));
  });

  test('flip vertical', () {
    expect(makeIraSquareSet('''
. 1 1 1 1 . . .
. 1 . . . 1 . .
. 1 . . . 1 . .
. 1 . . 1 . . .
. 1 1 1 . . . .
. 1 . 1 . . . .
. 1 . . 1 . . .
. 1 . . . 1 . .
''').flipVertical(), makeIraSquareSet('''
. 1 . . . 1 . .
. 1 . . 1 . . .
. 1 . 1 . . . .
. 1 1 1 . . . .
. 1 . . 1 . . .
. 1 . . . 1 . .
. 1 . . . 1 . .
. 1 1 1 1 . . .
'''));
  });

  test('mirror horizontal', () {
    expect(makeIraSquareSet('''
. 1 1 1 1 . . .
. 1 . . . 1 . .
. 1 . . . 1 . .
. 1 . . 1 . . .
. 1 1 1 . . . .
. 1 . 1 . . . .
. 1 . . 1 . . .
. 1 . . . 1 . .
''').mirrorHorizontal(), makeIraSquareSet('''
. . . 1 1 1 1 .
. . 1 . . . 1 .
. . 1 . . . 1 .
. . . 1 . . 1 .
. . . . 1 1 1 .
. . . . 1 . 1 .
. . . 1 . . 1 .
. . 1 . . . 1 .
'''));
  });
}
