import './square_set.dart';
import './utils.dart';
import './models.dart';

/// Gets squares attacked or defended by a king on [Square].
IraSquareSet kingAttacks(Square square) {
  assert(square >= 0 && square < 64);
  return _kingAttacks[square];
}

/// Gets squares attacked or defended by a knight on [Square].
IraSquareSet knightAttacks(Square square) {
  assert(square >= 0 && square < 64);
  return _knightAttacks[square];
}

/// Gets squares attacked or defended by a pawn of the given [Side] on [Square].
IraSquareSet pawnAttacks(Side side, Square square) {
  assert(square >= 0 && square < 64);
  return _pawnAttacks[side]![square];
}

/// Gets squares attacked or defended by a bishop on [Square], given `occupied`
/// squares.
IraSquareSet bishopAttacks(Square square, IraSquareSet occupied) {
  final bit = IraSquareSet.fromSquare(square);
  return _hyperbola(bit, _diagRange[square], occupied) ^
      _hyperbola(bit, _antiDiagRange[square], occupied);
}

/// Gets squares attacked or defended by a rook on [Square], given `occupied`
/// squares.
IraSquareSet rookAttacks(Square square, IraSquareSet occupied) {
  return _fileAttacks(square, occupied) ^ _rankAttacks(square, occupied);
}

/// Gets squares attacked or defended by a queen on [Square], given `occupied`
/// squares.
IraSquareSet queenAttacks(Square square, IraSquareSet occupied) =>
    bishopAttacks(square, occupied) ^ rookAttacks(square, occupied);

/// Gets squares attacked or defended by a `piece` on `square`, given
/// `occupied` squares.
IraSquareSet attacks(Piece piece, Square square, IraSquareSet occupied) {
  switch (piece.role) {
    case Role.pawn:
      return pawnAttacks(piece.color, square);
    case Role.knight:
      return knightAttacks(square);
    case Role.bishop:
      return bishopAttacks(square, occupied);
    case Role.rook:
      return rookAttacks(square, occupied);
    case Role.queen:
      return queenAttacks(square, occupied);
    case Role.king:
      return kingAttacks(square);
  }
}

/// Gets all squares of the rank, file or diagonal with the two squares
/// `a` and `b`, or an empty set if they are not aligned.
IraSquareSet ray(Square a, Square b) {
  final other = IraSquareSet.fromSquare(b);
  if (_rankRange[a].isIntersected(other)) {
    return _rankRange[a].withSquare(a);
  }
  if (_antiDiagRange[a].isIntersected(other)) {
    return _antiDiagRange[a].withSquare(a);
  }
  if (_diagRange[a].isIntersected(other)) {
    return _diagRange[a].withSquare(a);
  }
  if (_fileRange[a].isIntersected(other)) {
    return _fileRange[a].withSquare(a);
  }
  return IraSquareSet.empty;
}

/// Gets all squares between `a` and `b` (bounds not included), or an empty set
/// if they are not on the same rank, file or diagonal.
IraSquareSet between(Square a, Square b) => ray(a, b)
    .intersect(IraSquareSet.full.shl(a).xor(IraSquareSet.full.shl(b)))
    .withoutFirst();

// --

IraSquareSet _computeRange(Square square, List<int> deltas) {
  IraSquareSet range = IraSquareSet.empty;
  for (final delta in deltas) {
    final sq = square + delta;
    if (0 <= sq &&
        sq < 64 &&
        (squareFile(square) - squareFile(sq)).abs() <= 2) {
      range = range.withSquare(sq);
    }
  }
  return range;
}

List<T> _tabulate<T>(T Function(Square square) f) {
  final List<T> table = [];
  for (Square square = 0; square < 64; square++) {
    table.insert(square, f(square));
  }
  return table;
}

final _kingAttacks =
    _tabulate((sq) => _computeRange(sq, [-9, -8, -7, -1, 1, 7, 8, 9]));
final _knightAttacks =
    _tabulate((sq) => _computeRange(sq, [-17, -15, -10, -6, 6, 10, 15, 17]));
final _pawnAttacks = {
  Side.white: _tabulate((sq) => _computeRange(sq, [7, 9])),
  Side.black: _tabulate((sq) => _computeRange(sq, [-7, -9])),
};

final _fileRange =
    _tabulate((sq) => IraSquareSet.fromFile(squareFile(sq)).withoutSquare(sq));
final _rankRange =
    _tabulate((sq) => IraSquareSet.fromRank(squareRank(sq)).withoutSquare(sq));
final _diagRange = _tabulate((sq) {
  final shift = 8 * (squareRank(sq) - squareFile(sq));
  return (shift >= 0
          ? IraSquareSet.diagonal.shl(shift)
          : IraSquareSet.diagonal.shr(-shift))
      .withoutSquare(sq);
});
final _antiDiagRange = _tabulate((sq) {
  final shift = 8 * (squareRank(sq) + squareFile(sq) - 7);
  return (shift >= 0
          ? IraSquareSet.antidiagonal.shl(shift)
          : IraSquareSet.antidiagonal.shr(-shift))
      .withoutSquare(sq);
});

IraSquareSet _hyperbola(
    IraSquareSet bit, IraSquareSet range, IraSquareSet occupied) {
  IraSquareSet forward = occupied & range;
  IraSquareSet reverse =
      forward.flipVertical(); // Assumes no more than 1 bit per rank
  forward = forward - bit;
  reverse = reverse - bit.flipVertical();
  return (forward ^ reverse.flipVertical()) & range;
}

IraSquareSet _fileAttacks(Square square, IraSquareSet occupied) =>
    _hyperbola(IraSquareSet.fromSquare(square), _fileRange[square], occupied);

IraSquareSet _rankAttacks(Square square, IraSquareSet occupied) {
  final range = _rankRange[square];
  final bit = IraSquareSet.fromSquare(square);
  IraSquareSet forward = occupied & range;
  IraSquareSet reverse = forward.mirrorHorizontal();
  forward = forward - bit;
  reverse = reverse - bit.mirrorHorizontal();
  return (forward ^ reverse.mirrorHorizontal()) & range;
}
