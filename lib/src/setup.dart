import 'package:meta/meta.dart';
import 'dart:math' as math;
import './square_set.dart';
import './models.dart';
import './board.dart';
import './utils.dart';
import './constants.dart';

/// A not necessarily legal position.
@immutable
class Setup {
  /// Piece positions on the board.
  final Board board;

  /// Side to move.
  final Side turn;

  /// Unmoved rooks positions used to determine castling rights.
  final IraSquareSet unmovedRooks;

  /// En passant target square.
  ///
  /// Valid target squares are on the third or sixth rank.
  final Square? epSquare;

  /// Number of half-moves since the last capture or pawn move.
  final int halfmoves;

  /// Current move number.
  final int fullmoves;

  /// Number of remainingChecks for white and black.
  final (int, int)? remainingChecks;

  const Setup({
    required this.board,
    required this.turn,
    required this.unmovedRooks,
    this.epSquare,
    required this.halfmoves,
    required this.fullmoves,
    this.remainingChecks,
  });

  static const standard = Setup(
    board: Board.standard,
    turn: Side.white,
    unmovedRooks: IraSquareSet.corners,
    halfmoves: 0,
    fullmoves: 1,
  );

  /// Parse Forsyth-Edwards-Notation and returns a Setup.
  ///
  /// The parser is relaxed:
  ///
  /// * Supports X-FEN and Shredder-FEN for castling right notation.
  /// * Accepts missing FEN fields (except the board) and fills them with
  ///   default values of `8/8/8/8/8/8/8/8 w - - 0 1`.
  /// * Accepts multiple spaces and underscores (`_`) as separators between
  ///   FEN fields.
  ///
  /// Throws a [FenError] if the provided FEN is not valid.
  factory Setup.parseFen(String fen) {
    final parts = fen.split(RegExp(r'[\s_]+'));
    if (parts.isEmpty) throw const FenError('ERR_FEN');

    // board
    final boardPart = parts.removeAt(0);
    final board = Board.parseFen(boardPart);

    // turn
    Side turn;
    if (parts.isEmpty) {
      turn = Side.white;
    } else {
      final turnPart = parts.removeAt(0);
      if (turnPart == 'w') {
        turn = Side.white;
      } else if (turnPart == 'b') {
        turn = Side.black;
      } else {
        throw const FenError('ERR_TURN');
      }
    }

    // Castling
    IraSquareSet unmovedRooks;
    if (parts.isEmpty) {
      unmovedRooks = IraSquareSet.empty;
    } else {
      final castlingPart = parts.removeAt(0);
      unmovedRooks = _parseCastlingFen(board, castlingPart);
    }

    // En passant square
    Square? epSquare;
    if (parts.isNotEmpty) {
      final epPart = parts.removeAt(0);
      if (epPart != '-') {
        epSquare = parseSquare(epPart);
        if (epSquare == null) throw const FenError('ERR_EP_SQUARE');
      }
    }

    // move counters or remainingChecks
    String? halfmovePart = parts.isNotEmpty ? parts.removeAt(0) : null;
    (int, int)? earlyRemainingChecks;
    if (halfmovePart != null && halfmovePart.contains('+')) {
      earlyRemainingChecks = _parseRemainingChecks(halfmovePart);
      halfmovePart = parts.isNotEmpty ? parts.removeAt(0) : null;
    }
    final halfmoves = halfmovePart != null ? _parseSmallUint(halfmovePart) : 0;
    if (halfmoves == null) {
      throw const FenError('ERR_HALFMOVES');
    }

    final fullmovesPart = parts.isNotEmpty ? parts.removeAt(0) : null;
    final fullmoves =
        fullmovesPart != null ? _parseSmallUint(fullmovesPart) : 1;
    if (fullmoves == null) {
      throw const FenError('ERR_FULLMOVES');
    }

    final remainingChecksPart = parts.isNotEmpty ? parts.removeAt(0) : null;
    (int, int)? remainingChecks;
    if (remainingChecksPart != null) {
      if (earlyRemainingChecks != null) {
        throw const FenError('ERR_REMAINING_CHECKS');
      }
      remainingChecks = _parseRemainingChecks(remainingChecksPart);
    } else if (earlyRemainingChecks != null) {
      remainingChecks = earlyRemainingChecks;
    }

    if (parts.isNotEmpty) {
      throw const FenError('ERR_FEN');
    }

    return Setup(
      board: board,
      turn: turn,
      unmovedRooks: unmovedRooks,
      epSquare: epSquare,
      halfmoves: halfmoves,
      fullmoves: fullmoves,
      remainingChecks: remainingChecks,
    );
  }

  String get turnLetter => turn.name[0];

  String get fen => [
        board.fen,
        turnLetter,
        _makeCastlingFen(board, unmovedRooks),
        if (epSquare != null) toAlgebraic(epSquare!) else '-',
        if (remainingChecks != null) _makeRemainingChecks(remainingChecks!),
        math.max(0, math.min(halfmoves, 9999)),
        math.max(1, math.min(fullmoves, 9999)),
      ].join(' ');

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Setup &&
            other.board == board &&
            other.turn == turn &&
            other.unmovedRooks == unmovedRooks &&
            other.epSquare == epSquare &&
            other.halfmoves == halfmoves &&
            other.fullmoves == fullmoves;
  }

  @override
  int get hashCode => Object.hash(
        board,
        turn,
        unmovedRooks,
        epSquare,
        halfmoves,
        fullmoves,
      );
}

(int, int) _parseRemainingChecks(String part) {
  final parts = part.split('+');
  if (parts.length == 3 && parts[0] == '') {
    final white = _parseSmallUint(parts[1]);
    final black = _parseSmallUint(parts[2]);
    if (white == null || white > 3 || black == null || black > 3) {
      throw const FenError('ERR_REMAINING_CHECKS');
    }
    return (3 - white, 3 - black);
  } else if (parts.length == 2) {
    final white = _parseSmallUint(parts[0]);
    final black = _parseSmallUint(parts[1]);
    if (white == null || white > 3 || black == null || black > 3) {
      throw const FenError('ERR_REMAINING_CHECKS');
    }
    return (white, black);
  } else {
    throw const FenError('ERR_REMAINING_CHECKS');
  }
}

IraSquareSet _parseCastlingFen(Board board, String castlingPart) {
  IraSquareSet unmovedRooks = IraSquareSet.empty;
  if (castlingPart == '-') {
    return unmovedRooks;
  }
  for (int i = 0; i < castlingPart.length; i++) {
    final c = castlingPart[i];
    final lower = c.toLowerCase();
    final color = c == lower ? Side.black : Side.white;
    final backrankMask = IraSquareSet.backrankOf(color);
    final backrank = backrankMask & board.bySide(color);

    Iterable<Square> candidates;
    if (lower == 'q') {
      candidates = backrank.squares;
    } else if (lower == 'k') {
      candidates = backrank.squaresReversed;
    } else if ('a'.compareTo(lower) <= 0 && lower.compareTo('h') <= 0) {
      candidates =
          (IraSquareSet.fromFile(lower.codeUnitAt(0) - 'a'.codeUnitAt(0)) &
                  backrank)
              .squares;
    } else {
      throw const FenError('ERR_CASTLING');
    }
    for (final square in candidates) {
      if (board.kings.has(square)) break;
      if (board.rooks.has(square)) {
        unmovedRooks = unmovedRooks.withSquare(square);
        break;
      }
    }
  }
  if ((const IraSquareSet.fromRank(0) & unmovedRooks).size > 2 ||
      (const IraSquareSet.fromRank(7) & unmovedRooks).size > 2) {
    throw const FenError('ERR_CASTLING');
  }
  return unmovedRooks;
}

String _makeCastlingFen(Board board, IraSquareSet unmovedRooks) {
  final buffer = StringBuffer();
  for (final color in Side.values) {
    final backrank = IraSquareSet.backrankOf(color);
    final king = board.kingOf(color);
    final candidates =
        board.byPiece(Piece(color: color, role: Role.rook)) & backrank;
    for (final rook in (unmovedRooks & candidates).squaresReversed) {
      if (rook == candidates.first && king != null && rook < king) {
        buffer.write(color == Side.white ? 'Q' : 'q');
      } else if (rook == candidates.last && king != null && king < rook) {
        buffer.write(color == Side.white ? 'K' : 'k');
      } else {
        final file = kFileNames[squareFile(rook)];
        buffer.write(color == Side.white ? file.toUpperCase() : file);
      }
    }
  }
  final fen = buffer.toString();
  return fen != '' ? fen : '-';
}

String _makeRemainingChecks((int, int) checks) {
  final (white, black) = checks;
  return '$white+$black';
}

int? _parseSmallUint(String str) =>
    RegExp(r'^\d{1,4}$').hasMatch(str) ? int.parse(str) : null;
