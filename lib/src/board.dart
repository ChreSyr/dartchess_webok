import 'package:meta/meta.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import './square_set.dart';
import './models.dart';
import './attacks.dart';

/// A board represented by several square sets for each piece.
@immutable
class Board {
  const Board({
    required this.occupied,
    required this.white,
    required this.black,
    required this.pawns,
    required this.knights,
    required this.bishops,
    required this.rooks,
    required this.queens,
    required this.kings,
  });

  /// All occupied squares.
  final IraSquareSet occupied;

  /// All squares occupied by white pieces.
  final IraSquareSet white;

  /// All squares occupied by black pieces.
  final IraSquareSet black;

  /// All squares occupied by pawns.
  final IraSquareSet pawns;

  /// All squares occupied by knights.
  final IraSquareSet knights;

  /// All squares occupied by bishops.
  final IraSquareSet bishops;

  /// All squares occupied by rooks.
  final IraSquareSet rooks;

  /// All squares occupied by queens.
  final IraSquareSet queens;

  /// All squares occupied by kings.
  final IraSquareSet kings;

  /// Standard chess starting position.
  static const standard = Board(
    occupied: IraSquareSet(0xffff00000000ffff),
    white: IraSquareSet(0xffff),
    black: IraSquareSet(0xffff000000000000),
    pawns: IraSquareSet(0x00ff00000000ff00),
    knights: IraSquareSet(0x4200000000000042),
    bishops: IraSquareSet(0x2400000000000024),
    rooks: IraSquareSet.corners,
    queens: IraSquareSet(0x0800000000000008),
    kings: IraSquareSet(0x1000000000000010),
  );

  /// Racing Kings start position
  static const racingKings = Board(
      occupied: IraSquareSet(0xffff),
      white: IraSquareSet(0xf0f0),
      black: IraSquareSet(0x0f0f),
      pawns: IraSquareSet.empty,
      knights: IraSquareSet(0x1818),
      bishops: IraSquareSet(0x2424),
      rooks: IraSquareSet(0x4242),
      queens: IraSquareSet(0x0081),
      kings: IraSquareSet(0x8100));

  /// Horde start Positioin
  static const horde = Board(
    occupied: IraSquareSet(0xffff0066ffffffff),
    white: IraSquareSet(0x00000066ffffffff),
    black: IraSquareSet(0xffff000000000000),
    pawns: IraSquareSet(0x00ff0066ffffffff),
    knights: IraSquareSet(0x4200000000000000),
    bishops: IraSquareSet(0x2400000000000000),
    rooks: IraSquareSet(0x8100000000000000),
    queens: IraSquareSet(0x0800000000000000),
    kings: IraSquareSet(0x1000000000000000),
  );

  static const empty = Board(
    occupied: IraSquareSet.empty,
    white: IraSquareSet.empty,
    black: IraSquareSet.empty,
    pawns: IraSquareSet.empty,
    knights: IraSquareSet.empty,
    bishops: IraSquareSet.empty,
    rooks: IraSquareSet.empty,
    queens: IraSquareSet.empty,
    kings: IraSquareSet.empty,
  );

  /// Parse the board part of a FEN string and returns a Board.
  ///
  /// Throws a [FenError] if the provided FEN string is not valid.
  factory Board.parseFen(String boardFen) {
    Board board = Board.empty;
    int rank = 7;
    int file = 0;
    for (int i = 0; i < boardFen.length; i++) {
      final c = boardFen[i];
      if (c == '/' && file == 8) {
        file = 0;
        rank--;
      } else {
        final code = c.codeUnitAt(0);
        if (code < 57) {
          file += code - 48;
        } else {
          if (file >= 8 || rank < 0) throw const FenError('ERR_BOARD');
          final square = file + rank * 8;
          final piece = _charToPiece(c);
          if (piece == null) throw const FenError('ERR_BOARD');
          board = board.setPieceAt(square, piece);
          file++;
        }
      }
    }
    if (rank != 0 || file != 8) throw const FenError('ERR_BOARD');
    return board;
  }

  IraSquareSet get rooksAndQueens => rooks | queens;
  IraSquareSet get bishopsAndQueens => bishops | queens;

  /// Board part of the Forsyth-Edwards-Notation.
  String get fen {
    final buffer = StringBuffer();
    int empty = 0;
    for (int rank = 7; rank >= 0; rank--) {
      for (int file = 0; file < 8; file++) {
        final square = file + rank * 8;
        final piece = pieceAt(square);
        if (piece == null) {
          empty++;
        } else {
          if (empty > 0) {
            buffer.write(empty.toString());
            empty = 0;
          }
          buffer.write(piece.fenChar);
        }

        if (file == 7) {
          if (empty > 0) {
            buffer.write(empty.toString());
            empty = 0;
          }
          if (rank != 0) buffer.write('/');
        }
      }
    }
    return buffer.toString();
  }

  /// An iterable of each [Piece] associated to its [Square].
  Iterable<(Square, Piece)> get pieces sync* {
    for (final square in occupied.squares) {
      yield (square, pieceAt(square)!);
    }
  }

  /// Gets the number of pieces of each [Role] for the given [Side].
  IMap<Role, int> materialCount(Side side) => IMap.fromEntries(
      Role.values.map((role) => MapEntry(role, piecesOf(side, role).size)));

  /// A [IraSquareSet] of all the pieces matching this [Side] and [Role].
  IraSquareSet piecesOf(Side side, Role role) {
    return bySide(side) & byRole(role);
  }

  /// Gets all squares occupied by [Side].
  IraSquareSet bySide(Side side) => side == Side.white ? white : black;

  /// Gets all squares occupied by [Role].
  IraSquareSet byRole(Role role) {
    switch (role) {
      case Role.pawn:
        return pawns;
      case Role.knight:
        return knights;
      case Role.bishop:
        return bishops;
      case Role.rook:
        return rooks;
      case Role.queen:
        return queens;
      case Role.king:
        return kings;
    }
  }

  /// Gets all squares occupied by [Piece].
  IraSquareSet byPiece(Piece piece) {
    return bySide(piece.color) & byRole(piece.role);
  }

  /// Gets the [Side] at this [Square], if any.
  Side? sideAt(Square square) {
    if (bySide(Side.white).has(square)) {
      return Side.white;
    } else if (bySide(Side.black).has(square)) {
      return Side.black;
    } else {
      return null;
    }
  }

  /// Gets the [Role] at this [Square], if any.
  Role? roleAt(Square square) {
    for (final role in Role.values) {
      if (byRole(role).has(square)) {
        return role;
      }
    }
    return null;
  }

  /// Gets the [Piece] at this [Square], if any.
  Piece? pieceAt(Square square) {
    final side = sideAt(square);
    if (side == null) {
      return null;
    }
    final role = roleAt(square)!;
    return Piece(color: side, role: role);
  }

  /// Finds the unique king [Square] of the given [Side], if any.
  Square? kingOf(Side side) {
    return byPiece(Piece(color: side, role: Role.king)).singleSquare;
  }

  /// Finds the squares who are attacking `square` by the `attacker` [Side].
  IraSquareSet attacksTo(Square square, Side attacker,
          {IraSquareSet? occupied}) =>
      bySide(attacker).intersect(rookAttacks(square, occupied ?? this.occupied)
          .intersect(rooksAndQueens)
          .union(bishopAttacks(square, occupied ?? this.occupied)
              .intersect(bishopsAndQueens))
          .union(knightAttacks(square).intersect(knights))
          .union(kingAttacks(square).intersect(kings))
          .union(pawnAttacks(attacker.opposite, square).intersect(pawns)));

  /// Puts a [Piece] on a [Square] overriding the existing one, if any.
  Board setPieceAt(Square square, Piece piece) {
    return removePieceAt(square)._copyWith(
      occupied: occupied.withSquare(square),
      white: piece.color == Side.white ? white.withSquare(square) : null,
      black: piece.color == Side.black ? black.withSquare(square) : null,
      pawns: piece.role == Role.pawn ? pawns.withSquare(square) : null,
      knights: piece.role == Role.knight ? knights.withSquare(square) : null,
      bishops: piece.role == Role.bishop ? bishops.withSquare(square) : null,
      rooks: piece.role == Role.rook ? rooks.withSquare(square) : null,
      queens: piece.role == Role.queen ? queens.withSquare(square) : null,
      kings: piece.role == Role.king ? kings.withSquare(square) : null,
    );
  }

  /// Removes the [Piece] at this [Square] if it exists.
  Board removePieceAt(Square square) {
    final piece = pieceAt(square);
    return piece != null
        ? _copyWith(
            occupied: occupied.withoutSquare(square),
            white:
                piece.color == Side.white ? white.withoutSquare(square) : null,
            black:
                piece.color == Side.black ? black.withoutSquare(square) : null,
            pawns: piece.role == Role.pawn ? pawns.withoutSquare(square) : null,
            knights: piece.role == Role.knight
                ? knights.withoutSquare(square)
                : null,
            bishops: piece.role == Role.bishop
                ? bishops.withoutSquare(square)
                : null,
            rooks: piece.role == Role.rook ? rooks.withoutSquare(square) : null,
            queens:
                piece.role == Role.queen ? queens.withoutSquare(square) : null,
            kings: piece.role == Role.king ? kings.withoutSquare(square) : null,
          )
        : this;
  }

  Board _copyWith({
    IraSquareSet? occupied,
    IraSquareSet? white,
    IraSquareSet? black,
    IraSquareSet? pawns,
    IraSquareSet? knights,
    IraSquareSet? bishops,
    IraSquareSet? rooks,
    IraSquareSet? queens,
    IraSquareSet? kings,
  }) {
    return Board(
      occupied: occupied ?? this.occupied,
      white: white ?? this.white,
      black: black ?? this.black,
      pawns: pawns ?? this.pawns,
      knights: knights ?? this.knights,
      bishops: bishops ?? this.bishops,
      rooks: rooks ?? this.rooks,
      queens: queens ?? this.queens,
      kings: kings ?? this.kings,
    );
  }

  @override
  String toString() => fen;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Board &&
            other.occupied == occupied &&
            other.white == white &&
            other.black == black &&
            other.pawns == pawns &&
            other.knights == knights &&
            other.bishops == bishops &&
            other.rooks == rooks &&
            other.queens == queens &&
            other.kings == kings;
  }

  @override
  int get hashCode => Object.hash(
      occupied, white, black, pawns,
      knights, bishops, rooks, queens, kings);
}

Piece? _charToPiece(String ch) {
  final role = Role.fromChar(ch);
  if (role != null) {
    return Piece(
        role: role,
        color: ch == ch.toLowerCase() ? Side.black : Side.white,
    );
  }
  return null;
}
