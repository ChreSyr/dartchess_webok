import 'package:meta/meta.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import './constants.dart';
import './square_set.dart';
import './attacks.dart';
import './models.dart';
import './board.dart';
import './setup.dart';
import './utils.dart';

/// A base class for playable chess positions.
///
/// See [Iratus] for a concrete implementation of standard rules.
@immutable
abstract class Position<T extends Position<T>> {
  const Position({
    required this.board,
    required this.turn,
    required this.castles,
    this.epSquare,
    required this.halfmoves,
    required this.fullmoves,
  });

  /// Piece positions on the board.
  final Board board;

  /// Side to move.
  final Side turn;

  /// Castling paths and unmoved rooks.
  final Castles castles;

  /// En passant target square.
  final Square? epSquare;

  /// Number of half-moves since the last capture or pawn move.
  final int halfmoves;

  /// Current move number.
  final int fullmoves;

  /// Abstract const constructor to be used by subclasses.
  const Position._initial()
      : board = Board.standard,
        turn = Side.white,
        castles = Castles.standard,
        epSquare = null,
        halfmoves = 0,
        fullmoves = 1;

  Position._fromSetupUnchecked(Setup setup)
      : board = setup.board,
        turn = setup.turn,
        castles = Castles.fromSetup(setup),
        epSquare = _validEpSquare(setup),
        halfmoves = setup.halfmoves,
        fullmoves = setup.fullmoves;

  Position<T> _copyWith({
    Board? board,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
  });

  /// Create a [Position] from a [Setup] and [Rules].
  static Position setupPosition(Rules rules, Setup setup,
      {bool? ignoreImpossibleCheck}) {
    switch (rules) {
      case Rules.chess:
        return Iratus.fromSetup(setup,
            ignoreImpossibleCheck: ignoreImpossibleCheck);
    }
  }

  /// Returns the initial [Position] for the corresponding [Rules].
  static Position initialPosition(Rules rules) {
    switch (rules) {
      case Rules.chess:
        return Iratus.initial;
    }
  }

  /// Gets the FEN string of this position.
  ///
  /// Contrary to the FEN given by [Setup], this should always be a legal
  /// position.
  String get fen {
    return Setup(
      board: board,
      turn: turn,
      unmovedRooks: castles.unmovedRooks,
      epSquare: _legalEpSquare(),
      halfmoves: halfmoves,
      fullmoves: fullmoves,
    ).fen;
  }

  /// Tests if the king is in check.
  bool get isCheck {
    final king = board.kingOf(turn);
    return king != null && checkers.isNotEmpty;
  }

  /// Tests if the game is over.
  bool get isGameOver =>
      isInsufficientMaterial || !hasSomeLegalMoves;

  /// Tests for checkmate.
  bool get isCheckmate =>
      checkers.isNotEmpty && !hasSomeLegalMoves;

  /// Tests for stalemate.
  bool get isStalemate =>
      checkers.isEmpty && !hasSomeLegalMoves;

  /// The outcome of the game, or `null` if the game is not over.
  Outcome? get outcome {
    if (isCheckmate) {
      return Outcome(winner: turn.opposite);
    } else if (isInsufficientMaterial || isStalemate) {
      return Outcome.draw;
    } else {
      return null;
    }
  }

  /// Tests if both [Side] have insufficient winning material.
  bool get isInsufficientMaterial =>
      Side.values.every((side) => hasInsufficientMaterial(side));

  /// Tests if the position has at least one legal move.
  bool get hasSomeLegalMoves {
    final context = _makeContext();
    for (final square in board.bySide(turn).squares) {
      if (_legalMovesOf(square, context: context).isNotEmpty) return true;
    }
    return false;
  }

  /// Gets all the legal moves of this position.
  IMap<Square, IraSquareSet> get legalMoves {
    final context = _makeContext();
    return IMap({
      for (final s in board.bySide(turn).squares)
        s: _legalMovesOf(s, context: context)
    });
  }

  /// Gets all the legal drops of this position.
  IraSquareSet get legalDrops => IraSquareSet.empty;

  /// IraSquareSet of pieces giving check.
  IraSquareSet get checkers {
    final king = board.kingOf(turn);
    return king != null
        ? kingAttackers(king, turn.opposite)
        : IraSquareSet.empty;
  }

  /// Attacks that a king on `square` would have to deal with.
  IraSquareSet kingAttackers(Square square, Side attacker,
      {IraSquareSet? occupied}) {
    return board.attacksTo(square, attacker, occupied: occupied);
  }

  /// Tests if a [Side] has insufficient winning material.
  bool hasInsufficientMaterial(Side side) {
    if (board.bySide(side).isIntersected(board.pawns | board.rooksAndQueens)) {
      return false;
    }
    if (board.bySide(side).isIntersected(board.knights)) {
      return board.bySide(side).size <= 2 &&
          board
              .bySide(side.opposite)
              .diff(board.kings)
              .diff(board.queens)
              .isEmpty;
    }
    if (board.bySide(side).isIntersected(board.bishops)) {
      final sameColor =
          !board.bishops.isIntersected(IraSquareSet.darkSquares) ||
              !board.bishops.isIntersected(IraSquareSet.lightSquares);
      return sameColor && board.pawns.isEmpty && board.knights.isEmpty;
    }
    return true;
  }

  /// Tests a move for legality.
  bool isLegal(Move move) {
    switch (move) {
      case NormalMove(from: final f, to: final t, promotion: final p):
        if (p == Role.pawn) return false;
        if (p == Role.king) return false;
        if (p != null &&
            (!board.pawns.has(f) || !IraSquareSet.backranks.has(t))) {
          return false;
        }
        final legalMoves = _legalMovesOf(f);
        return legalMoves.has(t) || legalMoves.has(normalizeMove(move).to);
    }
  }

  /// Gets the legal moves for that [Square].
  IraSquareSet legalMovesOf(Square square) {
    return _legalMovesOf(square);
  }

  /// Parses a move in Standard Algebraic Notation.
  ///
  /// Returns a legal [Move] of the [Position] or `null`.
  Move? parseSan(String sanString) {
    final aIndex = 'a'.codeUnits[0];
    final hIndex = 'h'.codeUnits[0];
    final oneIndex = '1'.codeUnits[0];
    final eightIndex = '8'.codeUnits[0];
    String san = sanString;

    final firstAnnotationIndex = san.indexOf(RegExp('[!?#+]'));
    if (firstAnnotationIndex != -1) {
      san = san.substring(0, firstAnnotationIndex);
    }

    if (san == 'O-O') {
      final king = board.kingOf(turn);
      final rook = castles.rookOf(turn, CastlingSide.king);
      if (king == null || rook == null) {
        return null;
      }
      final move = NormalMove(from: king, to: rook);
      if (!isLegal(move)) {
        return null;
      }
      return move;
    }
    if (san == 'O-O-O') {
      final king = board.kingOf(turn);
      final rook = castles.rookOf(turn, CastlingSide.queen);
      if (king == null || rook == null) {
        return null;
      }
      final move = NormalMove(from: king, to: rook);
      if (!isLegal(move)) {
        return null;
      }
      return move;
    }

    final isPromotion = san.contains('=');
    final isCapturing = san.contains('x');
    int? pawnRank;
    if (oneIndex <= san.codeUnits[0] && san.codeUnits[0] <= eightIndex) {
      pawnRank = san.codeUnits[0] - oneIndex;
      san = san.substring(1);
    }
    final isPawnMove = aIndex <= san.codeUnits[0] && san.codeUnits[0] <= hIndex;

    if (isPawnMove) {
      // Every pawn move has a destination (e.g. d4)
      // Optionally, pawn moves have a promotion
      // If the move is a capture then it will include the source file

      final colorFilter = board.bySide(turn);
      final pawnFilter = board.byRole(Role.pawn);
      IraSquareSet filter = colorFilter.intersect(pawnFilter);
      Role? promotionRole;

      // We can look at the first character of any pawn move
      // in order to determine which file the pawn will be moving
      // from
      final sourceFileCharacter = san.codeUnits[0];
      if (sourceFileCharacter < aIndex || sourceFileCharacter > hIndex) {
        return null;
      }

      final sourceFile = sourceFileCharacter - aIndex;
      final sourceFileFilter = IraSquareSet.fromFile(sourceFile);
      filter = filter.intersect(sourceFileFilter);

      if (isCapturing) {
        // Invalid SAN
        if (san[1] != 'x') {
          return null;
        }

        // Remove the source file character and the capture marker
        san = san.substring(2);
      }

      if (isPromotion) {
        // Invalid SAN
        if (san[san.length - 2] != '=') {
          return null;
        }

        final promotionCharacter = san[san.length - 1];
        promotionRole = Role.fromChar(promotionCharacter);

        // Remove the promotion string
        san = san.substring(0, san.length - 2);
      }

      // After handling captures and promotions, the
      // remaining destination square should contain
      // two characters.
      if (san.length != 2) {
        return null;
      }

      final destination = parseSquare(san);
      if (destination == null) {
        return null;
      }

      // There may be many pawns in the corresponding file
      // The corect choice will always be the pawn behind the destination square that is furthest down the board
      for (int rank = 0; rank < 8; rank++) {
        final rankFilter = IraSquareSet.fromRank(rank).complement();
        // If the square is behind or on this rank, the rank it will not contain the source pawn
        if (turn == Side.white && rank >= squareRank(destination) ||
            turn == Side.black && rank <= squareRank(destination)) {
          filter = filter.intersect(rankFilter);
        }
      }

      // If the pawn rank has been overspecified, then verify the rank
      if (pawnRank != null) {
        filter = filter.intersect(IraSquareSet.fromRank(pawnRank));
      }

      final source = (turn == Side.white) ? filter.last : filter.first;

      // There are no valid candidates for the move
      if (source == null) {
        return null;
      }

      final move =
          NormalMove(from: source, to: destination, promotion: promotionRole);
      if (!isLegal(move)) {
        return null;
      }
      return move;
    }

    // The final two moves define the destination
    final destination = parseSquare(san.substring(san.length - 2));
    if (destination == null) {
      return null;
    }

    san = san.substring(0, san.length - 2);
    if (isCapturing) {
      // Invalid SAN
      if (san[san.length - 1] != 'x') {
        return null;
      }
      san = san.substring(0, san.length - 1);
    }

    // For non-pawn moves, the first character describes a role
    final role = Role.fromChar(san[0]);
    if (role == null) {
      return null;
    }
    if (role == Role.pawn) {
      return null;
    }
    san = san.substring(1);

    final colorFilter = board.bySide(turn);
    final roleFilter = board.byRole(role);
    IraSquareSet filter = colorFilter.intersect(roleFilter);

    // The remaining characters disambiguate the moves
    if (san.length > 2) {
      return null;
    }
    if (san.length == 2) {
      final sourceSquare = parseSquare(san);
      if (sourceSquare == null) {
        return null;
      }
      final squareFilter = IraSquareSet.fromSquare(sourceSquare);
      filter = filter.intersect(squareFilter);
    }
    if (san.length == 1) {
      final sourceCharacter = san.codeUnits[0];
      if (oneIndex <= sourceCharacter && sourceCharacter <= eightIndex) {
        final rank = sourceCharacter - oneIndex;
        final rankFilter = IraSquareSet.fromRank(rank);
        filter = filter.intersect(rankFilter);
      } else if (aIndex <= sourceCharacter && sourceCharacter <= hIndex) {
        final file = sourceCharacter - aIndex;
        final fileFilter = IraSquareSet.fromFile(file);
        filter = filter.intersect(fileFilter);
      } else {
        return null;
      }
    }

    Move? move;
    for (final square in filter.squares) {
      final candidateMove = NormalMove(from: square, to: destination);
      if (!isLegal(candidateMove)) {
        continue;
      }
      if (move == null) {
        move = candidateMove;
      } else {
        // Ambiguous notation
        return null;
      }
    }

    if (move == null) {
      return null;
    }

    return move;
  }

  /// Plays a move and returns the updated [Position].
  ///
  /// Throws a [PlayError] if the move is not legal.
  Position<T> play(Move move) {
    if (isLegal(move)) {
      return playUnchecked(move);
    } else {
      throw PlayError('Invalid move $move');
    }
  }

  /// Plays a move without checking if the move is legal and returns the updated [Position].
  Position<T> playUnchecked(Move move) {
    switch (move) {
      case NormalMove(from: final from, to: final to, promotion: final prom):
        final piece = board.pieceAt(from);
        if (piece == null) {
          return _copyWith();
        }
        final castlingSide = _getCastlingSide(move);
        final epCaptureTarget = to + (turn == Side.white ? -8 : 8);
        Square? newEpSquare;
        Board newBoard = board.removePieceAt(from);
        Castles newCastles = castles;
        if (piece.role == Role.pawn) {
          if (to == epSquare) {
            newBoard = newBoard.removePieceAt(epCaptureTarget);
          }
          final delta = from - to;
          if (delta.abs() == 16 && from >= 8 && from <= 55) {
            newEpSquare = (from + to) >>> 1;
          }
        } else if (piece.role == Role.rook) {
          newCastles = newCastles.discardRookAt(from);
        } else if (piece.role == Role.king) {
          if (castlingSide != null) {
            final rookFrom = castles.rookOf(turn, castlingSide);
            if (rookFrom != null) {
              final rook = board.pieceAt(rookFrom);
              newBoard = newBoard
                  .removePieceAt(rookFrom)
                  .setPieceAt(_kingCastlesTo(turn, castlingSide), piece);
              if (rook != null) {
                newBoard = newBoard.setPieceAt(
                    _rookCastlesTo(turn, castlingSide), rook);
              }
            }
          }
          newCastles = newCastles.discardSide(turn);
        }

        if (castlingSide == null) {
          final newPiece = prom != null
              ? piece.copyWith(role: prom)
              : piece;
          newBoard = newBoard.setPieceAt(to, newPiece);
        }

        final capturedPiece = castlingSide == null
            ? board.pieceAt(to)
            : to == epSquare
                ? board.pieceAt(epCaptureTarget)
                : null;
        final isCapture = capturedPiece != null;

        if (capturedPiece != null && capturedPiece.role == Role.rook) {
          newCastles = newCastles.discardRookAt(to);
        }

        return _copyWith(
          halfmoves: isCapture || piece.role == Role.pawn ? 0 : halfmoves + 1,
          fullmoves: turn == Side.black ? fullmoves + 1 : fullmoves,
          board: newBoard,
          turn: turn.opposite,
          castles: newCastles,
          epSquare: Box(newEpSquare),
        );
    }
  }

  /// Returns the SAN of this [Move] and the updated [Position], without checking if the move is legal.
  (Position<T>, String) makeSanUnchecked(Move move) {
    final san = _makeSanWithoutSuffix(move);
    final newPos = playUnchecked(move);
    final suffixed = newPos.outcome?.winner != null
        ? '$san#'
        : newPos.isCheck
            ? '$san+'
            : san;
    return (newPos, suffixed);
  }

  /// Returns the SAN of this [Move] and the updated [Position].
  ///
  /// Throws a [PlayError] if the move is not legal.
  (Position<T>, String) makeSan(Move move) {
    if (isLegal(move)) {
      return makeSanUnchecked(move);
    } else {
      throw PlayError('Invalid move $move');
    }
  }

  /// Returns the SAN of this [Move] from the current [Position].
  ///
  /// Throws a [PlayError] if the move is not legal.
  @Deprecated('Use makeSan instead')
  String toSan(Move move) {
    if (isLegal(move)) {
      return makeSanUnchecked(move).$2;
    } else {
      throw PlayError('Invalid move $move');
    }
  }

  /// Returns the SAN representation of the [Move] with the updated [Position].
  ///
  /// Throws a [PlayError] if the move is not legal.
  @Deprecated('Use makeSan instead')
  (Position<T>, String) playToSan(Move move) {
    if (isLegal(move)) {
      final san = _makeSanWithoutSuffix(move);
      final newPos = playUnchecked(move);
      final suffixed = newPos.outcome?.winner != null
          ? '$san#'
          : newPos.isCheck
              ? '$san+'
              : san;
      return (newPos, suffixed);
    } else {
      throw PlayError('Invalid move $move');
    }
  }

  /// Returns the normalized form of a [NormalMove] to avoid castling inconsistencies.
  Move normalizeMove(NormalMove move) {
    final side = _getCastlingSide(move);
    if (side == null) return move;
    final castlingRook = castles.rookOf(turn, side);
    return NormalMove(
      from: move.from,
      to: castlingRook ?? move.to,
    );
  }

  /// Checks the legality of this position.
  ///
  /// Throws a [PositionError] if it does not meet basic validity requirements.
  void validate({bool? ignoreImpossibleCheck}) {
    if (board.occupied.isEmpty) {
      throw PositionError.empty;
    }
    if (board.kings.size != 2) {
      throw PositionError.kings;
    }
    final ourKing = board.kingOf(turn);
    if (ourKing == null) {
      throw PositionError.kings;
    }
    final otherKing = board.kingOf(turn.opposite);
    if (otherKing == null) {
      throw PositionError.kings;
    }
    if (kingAttackers(otherKing, turn).isNotEmpty) {
      throw PositionError.oppositeCheck;
    }
    if (IraSquareSet.backranks.isIntersected(board.pawns)) {
      throw PositionError.pawnsOnBackrank;
    }
    final skipImpossibleCheck = ignoreImpossibleCheck ?? false;
    if (!skipImpossibleCheck) {
      _validateCheckers(ourKing);
    }
  }

  @override
  String toString() {
    return '$T(board: $board, turn: $turn, castles: $castles, halfmoves: $halfmoves, fullmoves: $fullmoves)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Position &&
            other.board == board &&
            other.turn == turn &&
            other.castles == castles &&
            other.epSquare == epSquare &&
            other.halfmoves == halfmoves &&
            other.fullmoves == fullmoves;
  }

  @override
  int get hashCode => Object.hash(
        board,
        turn,
        castles,
        epSquare,
        halfmoves,
        fullmoves,
      );

  /// Checks if checkers are legal in this position.
  ///
  /// Throws a [PositionError.impossibleCheck] if it does not meet validity
  /// requirements.
  void _validateCheckers(Square ourKing) {
    final checkers = kingAttackers(ourKing, turn.opposite);
    if (checkers.isNotEmpty) {
      if (epSquare != null) {
        // The pushed pawn must be the only checker, or it has uncovered
        // check by a single sliding piece.
        final pushedTo = epSquare! ^ 8;
        final pushedFrom = epSquare! ^ 24;
        if (checkers.moreThanOne ||
            (checkers.first != pushedTo &&
                board
                    .attacksTo(ourKing, turn.opposite,
                        occupied: board.occupied
                            .withoutSquare(pushedTo)
                            .withSquare(pushedFrom))
                    .isNotEmpty)) {
          throw PositionError.impossibleCheck;
        }
      } else {
        // Multiple sliding checkers aligned with king.
        if (checkers.size > 2 ||
            (checkers.size == 2 &&
                ray(checkers.first!, checkers.last!).has(ourKing))) {
          throw PositionError.impossibleCheck;
        }
      }
    }
  }

  String _makeSanWithoutSuffix(Move move) {
    String san = '';
    switch (move) {
      case NormalMove(from: final from, to: final to, promotion: final prom):
        final role = board.roleAt(from);
        if (role == null) return '--';
        if (role == Role.king &&
            (board.bySide(turn).has(to) || (to - from).abs() == 2)) {
          san = to > from ? 'O-O' : 'O-O-O';
        } else {
          final capture = board.occupied.has(to) ||
              (role == Role.pawn && squareFile(from) != squareFile(to));
          if (role != Role.pawn) {
            san = role.char.toUpperCase();

            // Disambiguation
            IraSquareSet others;
            if (role == Role.king) {
              others = kingAttacks(to) & board.kings;
            } else if (role == Role.queen) {
              others = queenAttacks(to, board.occupied) & board.queens;
            } else if (role == Role.rook) {
              others = rookAttacks(to, board.occupied) & board.rooks;
            } else if (role == Role.bishop) {
              others = bishopAttacks(to, board.occupied) & board.bishops;
            } else {
              others = knightAttacks(to) & board.knights;
            }
            others = others.intersect(board.bySide(turn)).withoutSquare(from);

            if (others.isNotEmpty) {
              final ctx = _makeContext();
              for (final from in others.squares) {
                if (!_legalMovesOf(from, context: ctx).has(to)) {
                  others = others.withoutSquare(from);
                }
              }
              if (others.isNotEmpty) {
                bool row = false;
                bool column = others
                    .isIntersected(IraSquareSet.fromRank(squareRank(from)));
                if (others
                    .isIntersected(IraSquareSet.fromFile(squareFile(from)))) {
                  row = true;
                } else {
                  column = true;
                }
                if (column) {
                  san += kFileNames[squareFile(from)];
                }
                if (row) {
                  san += kRankNames[squareRank(from)];
                }
              }
            }
          } else if (capture) {
            san = kFileNames[squareFile(from)];
          }

          if (capture) san += 'x';
          san += toAlgebraic(to);
          if (prom != null) {
            san += '=${prom.char.toUpperCase()}';
          }
        }
    }
    return san;
  }

  /// Gets the legal moves for that [Square].
  ///
  /// Optionnaly pass a [_Context] of the position, to optimize performance when
  /// calling this method several times.
  IraSquareSet _legalMovesOf(Square square, {_Context? context}) {
    final ctx = context ?? _makeContext();
    final piece = board.pieceAt(square);
    if (piece == null || piece.color != turn) return IraSquareSet.empty;

    IraSquareSet pseudo;
    IraSquareSet? legalEpSquare;
    if (piece.role == Role.pawn) {
      pseudo = pawnAttacks(turn, square) & board.bySide(turn.opposite);
      final delta = turn == Side.white ? 8 : -8;
      final step = square + delta;
      if (0 <= step && step < 64 && !board.occupied.has(step)) {
        pseudo = pseudo.withSquare(step);
        final canDoubleStep =
            turn == Side.white ? square < 16 : square >= 64 - 16;
        final doubleStep = step + delta;
        if (canDoubleStep && !board.occupied.has(doubleStep)) {
          pseudo = pseudo.withSquare(doubleStep);
        }
      }
      if (epSquare != null && _canCaptureEp(square)) {
        final pawn = epSquare! - delta;
        if (ctx.checkers.isEmpty || ctx.checkers.singleSquare == pawn) {
          legalEpSquare = IraSquareSet.fromSquare(epSquare!);
        }
      }
    } else if (piece.role == Role.bishop) {
      pseudo = bishopAttacks(square, board.occupied);
    } else if (piece.role == Role.knight) {
      pseudo = knightAttacks(square);
    } else if (piece.role == Role.rook) {
      pseudo = rookAttacks(square, board.occupied);
    } else if (piece.role == Role.queen) {
      pseudo = queenAttacks(square, board.occupied);
    } else {
      pseudo = kingAttacks(square);
    }

    pseudo = pseudo.diff(board.bySide(turn));
    if (ctx.king != null) {
      if (piece.role == Role.king) {
        final occ = board.occupied.withoutSquare(square);
        for (final to in pseudo.squares) {
          if (kingAttackers(to, turn.opposite, occupied: occ).isNotEmpty) {
            pseudo = pseudo.withoutSquare(to);
          }
        }
        return pseudo
            .union(_castlingMove(CastlingSide.queen, ctx))
            .union(_castlingMove(CastlingSide.king, ctx));
      }

      if (ctx.checkers.isNotEmpty) {
        final checker = ctx.checkers.singleSquare;
        if (checker == null) return IraSquareSet.empty;
        pseudo = pseudo & between(checker, ctx.king!).withSquare(checker);
      }

      if (ctx.blockers.has(square)) {
        pseudo = pseudo & ray(square, ctx.king!);
      }
    }

    if (legalEpSquare != null) {
      pseudo = pseudo | legalEpSquare;
    }

    return pseudo;
  }

  _Context _makeContext() {
    final king = board.kingOf(turn);
    if (king == null) {
      return _Context(
          mustCapture: false,
          king: king,
          blockers: IraSquareSet.empty,
          checkers: IraSquareSet.empty);
    }
    return _Context(
      mustCapture: false,
      king: king,
      blockers: _sliderBlockers(king),
      checkers: checkers,
    );
  }

  IraSquareSet _sliderBlockers(Square king) {
    final snipers = rookAttacks(king, IraSquareSet.empty)
        .intersect(board.rooksAndQueens)
        .union(bishopAttacks(king, IraSquareSet.empty)
            .intersect(board.bishopsAndQueens))
        .intersect(board.bySide(turn.opposite));
    IraSquareSet blockers = IraSquareSet.empty;
    for (final sniper in snipers.squares) {
      final b = between(king, sniper) & board.occupied;
      if (!b.moreThanOne) blockers = blockers | b;
    }
    return blockers;
  }

  IraSquareSet _castlingMove(CastlingSide side, _Context context) {
    final king = context.king;
    if (king == null || context.checkers.isNotEmpty) {
      return IraSquareSet.empty;
    }
    final rook = castles.rookOf(turn, side);
    if (rook == null) return IraSquareSet.empty;
    if (castles.pathOf(turn, side).isIntersected(board.occupied)) {
      return IraSquareSet.empty;
    }

    final kingTo = _kingCastlesTo(turn, side);
    final kingPath = between(king, kingTo);
    final occ = board.occupied.withoutSquare(king);
    for (final sq in kingPath.squares) {
      if (kingAttackers(sq, turn.opposite, occupied: occ).isNotEmpty) {
        return IraSquareSet.empty;
      }
    }
    final rookTo = _rookCastlesTo(turn, side);
    final after = board.occupied
        .toggleSquare(king)
        .toggleSquare(rook)
        .toggleSquare(rookTo);
    if (kingAttackers(kingTo, turn.opposite, occupied: after).isNotEmpty) {
      return IraSquareSet.empty;
    }
    return IraSquareSet.fromSquare(rook);
  }

  bool _canCaptureEp(Square pawn) {
    if (epSquare == null) return false;
    if (!pawnAttacks(turn, pawn).has(epSquare!)) return false;
    final king = board.kingOf(turn);
    if (king == null) return true;
    final captured = epSquare! + (turn == Side.white ? -8 : 8);
    final occupied = board.occupied
        .toggleSquare(pawn)
        .toggleSquare(epSquare!)
        .toggleSquare(captured);
    return !board
        .attacksTo(king, turn.opposite, occupied: occupied)
        .isIntersected(occupied);
  }

  /// Detects if a move is a castling move.
  ///
  /// Returns the [CastlingSide] or `null` if the move is a drop move.
  CastlingSide? _getCastlingSide(Move move) {
    if (move case NormalMove(from: final from, to: final to)) {
      final delta = to - from;
      if (delta.abs() != 2 && !board.bySide(turn).has(to)) {
        return null;
      }
      if (!board.kings.has(from)) {
        return null;
      }
      return delta > 0 ? CastlingSide.king : CastlingSide.queen;
    }
    return null;
  }

  Square? _legalEpSquare() {
    if (epSquare == null) return null;
    final ourPawns = board.piecesOf(turn, Role.pawn);
    final candidates = ourPawns & pawnAttacks(turn.opposite, epSquare!);
    for (final candidate in candidates.squares) {
      if (_legalMovesOf(candidate).has(epSquare!)) {
        return epSquare;
      }
    }
    return null;
  }
}

/// A standard chess position.
@immutable
class Iratus extends Position<Iratus> {
  const Iratus({
    required super.board,
    required super.turn,
    required super.castles,
    super.epSquare,
    required super.halfmoves,
    required super.fullmoves,
  });

  Iratus._fromSetupUnchecked(super.setup) : super._fromSetupUnchecked();
  const Iratus._initial() : super._initial();

  static const initial = Iratus._initial();

  /// Set up a playable [Iratus] position.
  ///
  /// Throws a [PositionError] if the [Setup] does not meet basic validity
  /// requirements.
  /// Optionnaly pass a `ignoreImpossibleCheck` boolean if you want to skip that
  /// requirement.
  factory Iratus.fromSetup(Setup setup, {bool? ignoreImpossibleCheck}) {
    final pos = Iratus._fromSetupUnchecked(setup);
    pos.validate(ignoreImpossibleCheck: ignoreImpossibleCheck);
    return pos;
  }

  @override
  Iratus _copyWith({
    Board? board,
    Side? turn,
    Castles? castles,
    Box<Square?>? epSquare,
    int? halfmoves,
    int? fullmoves,
  }) {
    return Iratus(
      board: board ?? this.board,
      turn: turn ?? this.turn,
      castles: castles ?? this.castles,
      epSquare: epSquare != null ? epSquare.value : this.epSquare,
      halfmoves: halfmoves ?? this.halfmoves,
      fullmoves: fullmoves ?? this.fullmoves,
    );
  }
}

/// The outcome of a [Position]. No `winner` means a draw.
@immutable
class Outcome {
  const Outcome({this.winner});

  final Side? winner;

  static const whiteWins = Outcome(winner: Side.white);
  static const blackWins = Outcome(winner: Side.black);
  static const draw = Outcome();

  @override
  String toString() {
    return 'winner: $winner';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Outcome && winner == other.winner;

  @override
  int get hashCode => winner.hashCode;

  /// Create [Outcome] from string
  static Outcome? fromPgn(String? outcome) {
    if (outcome == '1/2-1/2') {
      return Outcome.draw;
    } else if (outcome == '1-0') {
      return Outcome.whiteWins;
    } else if (outcome == '0-1') {
      return Outcome.blackWins;
    } else {
      return null;
    }
  }

  /// Create PGN String out of [Outcome]
  static String toPgnString(Outcome? outcome) {
    if (outcome == null) {
      return '*';
    } else if (outcome.winner == Side.white) {
      return '1-0';
    } else if (outcome.winner == Side.black) {
      return '0-1';
    } else {
      return '1/2-1/2';
    }
  }
}

enum IllegalSetup {
  /// There are no pieces on the board.
  empty,

  /// The player not to move is in check.
  oppositeCheck,

  /// There are impossibly many checkers, two sliding checkers are
  /// aligned, or check is not possible because the last move was a
  /// double pawn push.
  ///
  /// Such a position cannot be reached by any sequence of legal moves.
  impossibleCheck,

  /// There are pawns on the backrank.
  pawnsOnBackrank,

  /// A king is missing, or there are too many kings.
  kings,

  /// A variant specific rule is violated.
  variant,
}

@immutable
class PlayError implements Exception {
  final String message;
  const PlayError(this.message);

  @override
  String toString() => 'PlayError($message)';
}

/// Error when trying to create a [Position] from an illegal [Setup].
@immutable
class PositionError implements Exception {
  final IllegalSetup cause;
  const PositionError(this.cause);

  static const empty = PositionError(IllegalSetup.empty);
  static const oppositeCheck = PositionError(IllegalSetup.oppositeCheck);
  static const impossibleCheck = PositionError(IllegalSetup.impossibleCheck);
  static const pawnsOnBackrank = PositionError(IllegalSetup.pawnsOnBackrank);
  static const kings = PositionError(IllegalSetup.kings);
  static const variant = PositionError(IllegalSetup.variant);

  @override
  String toString() => 'PositionError(${cause.name})';
}

@immutable
class Castles {
  /// IraSquareSet of rooks that have not moved yet.
  final IraSquareSet unmovedRooks;

  final Square? _whiteRookQueenSide;
  final Square? _whiteRookKingSide;
  final Square? _blackRookQueenSide;
  final Square? _blackRookKingSide;
  final IraSquareSet _whitePathQueenSide;
  final IraSquareSet _whitePathKingSide;
  final IraSquareSet _blackPathQueenSide;
  final IraSquareSet _blackPathKingSide;

  const Castles({
    required this.unmovedRooks,
    required Square? whiteRookQueenSide,
    required Square? whiteRookKingSide,
    required Square? blackRookQueenSide,
    required Square? blackRookKingSide,
    required IraSquareSet whitePathQueenSide,
    required IraSquareSet whitePathKingSide,
    required IraSquareSet blackPathQueenSide,
    required IraSquareSet blackPathKingSide,
  })  : _whiteRookQueenSide = whiteRookQueenSide,
        _whiteRookKingSide = whiteRookKingSide,
        _blackRookQueenSide = blackRookQueenSide,
        _blackRookKingSide = blackRookKingSide,
        _whitePathQueenSide = whitePathQueenSide,
        _whitePathKingSide = whitePathKingSide,
        _blackPathQueenSide = blackPathQueenSide,
        _blackPathKingSide = blackPathKingSide;

  static const standard = Castles(
    unmovedRooks: IraSquareSet.corners,
    whiteRookQueenSide: Squares.a1,
    whiteRookKingSide: Squares.h1,
    blackRookQueenSide: Squares.a8,
    blackRookKingSide: Squares.h8,
    whitePathQueenSide: IraSquareSet(0x000000000000000e),
    whitePathKingSide: IraSquareSet(0x0000000000000060),
    blackPathQueenSide: IraSquareSet(0x0e00000000000000),
    blackPathKingSide: IraSquareSet(0x6000000000000000),
  );

  static const empty = Castles(
    unmovedRooks: IraSquareSet.empty,
    whiteRookQueenSide: null,
    whiteRookKingSide: null,
    blackRookQueenSide: null,
    blackRookKingSide: null,
    whitePathQueenSide: IraSquareSet.empty,
    whitePathKingSide: IraSquareSet.empty,
    blackPathQueenSide: IraSquareSet.empty,
    blackPathKingSide: IraSquareSet.empty,
  );

  factory Castles.fromSetup(Setup setup) {
    Castles castles = Castles.empty;
    final rooks = setup.unmovedRooks & setup.board.rooks;
    for (final side in Side.values) {
      final backrank = IraSquareSet.backrankOf(side);
      final king = setup.board.kingOf(side);
      if (king == null || !backrank.has(king)) continue;
      final backrankRooks = rooks & setup.board.bySide(side) & backrank;
      if (backrankRooks.first != null && backrankRooks.first! < king) {
        castles =
            castles._add(side, CastlingSide.queen, king, backrankRooks.first!);
      }
      if (backrankRooks.last != null && king < backrankRooks.last!) {
        castles =
            castles._add(side, CastlingSide.king, king, backrankRooks.last!);
      }
    }
    return castles;
  }

  /// Gets rooks positions by side and castling side.
  BySide<ByCastlingSide<Square?>> get rooksPositions {
    return BySide({
      Side.white: ByCastlingSide({
        CastlingSide.queen: _whiteRookQueenSide,
        CastlingSide.king: _whiteRookKingSide,
      }),
      Side.black: ByCastlingSide({
        CastlingSide.queen: _blackRookQueenSide,
        CastlingSide.king: _blackRookKingSide,
      }),
    });
  }

  /// Gets rooks paths by side and castling side.
  BySide<ByCastlingSide<IraSquareSet>> get paths {
    return BySide({
      Side.white: ByCastlingSide({
        CastlingSide.queen: _whitePathQueenSide,
        CastlingSide.king: _whitePathKingSide,
      }),
      Side.black: ByCastlingSide({
        CastlingSide.queen: _blackPathQueenSide,
        CastlingSide.king: _blackPathKingSide,
      }),
    });
  }

  /// Gets the rook [Square] by side and castling side.
  Square? rookOf(Side side, CastlingSide cs) => cs == CastlingSide.queen
      ? side == Side.white
          ? _whiteRookQueenSide
          : _blackRookQueenSide
      : side == Side.white
          ? _whiteRookKingSide
          : _blackRookKingSide;

  /// Gets the squares that need to be empty so that castling is possible
  /// on the given side.
  ///
  /// We're assuming the player still has the required castling rigths.
  IraSquareSet pathOf(Side side, CastlingSide cs) => cs == CastlingSide.queen
      ? side == Side.white
          ? _whitePathQueenSide
          : _blackPathQueenSide
      : side == Side.white
          ? _whitePathKingSide
          : _blackPathKingSide;

  Castles discardRookAt(Square square) {
    return _copyWith(
      unmovedRooks: unmovedRooks.withoutSquare(square),
      whiteRookQueenSide:
          _whiteRookQueenSide == square ? const Box(null) : null,
      whiteRookKingSide: _whiteRookKingSide == square ? const Box(null) : null,
      blackRookQueenSide:
          _blackRookQueenSide == square ? const Box(null) : null,
      blackRookKingSide: _blackRookKingSide == square ? const Box(null) : null,
    );
  }

  Castles discardSide(Side side) {
    return _copyWith(
      unmovedRooks: unmovedRooks.diff(IraSquareSet.backrankOf(side)),
      whiteRookQueenSide: side == Side.white ? const Box(null) : null,
      whiteRookKingSide: side == Side.white ? const Box(null) : null,
      blackRookQueenSide: side == Side.black ? const Box(null) : null,
      blackRookKingSide: side == Side.black ? const Box(null) : null,
    );
  }

  Castles _add(Side side, CastlingSide cs, Square king, Square rook) {
    final kingTo = _kingCastlesTo(side, cs);
    final rookTo = _rookCastlesTo(side, cs);
    final path = between(rook, rookTo)
        .withSquare(rookTo)
        .union(between(king, kingTo).withSquare(kingTo))
        .withoutSquare(king)
        .withoutSquare(rook);
    return _copyWith(
      unmovedRooks: unmovedRooks.withSquare(rook),
      whiteRookQueenSide:
          side == Side.white && cs == CastlingSide.queen ? Box(rook) : null,
      whiteRookKingSide:
          side == Side.white && cs == CastlingSide.king ? Box(rook) : null,
      blackRookQueenSide:
          side == Side.black && cs == CastlingSide.queen ? Box(rook) : null,
      blackRookKingSide:
          side == Side.black && cs == CastlingSide.king ? Box(rook) : null,
      whitePathQueenSide:
          side == Side.white && cs == CastlingSide.queen ? path : null,
      whitePathKingSide:
          side == Side.white && cs == CastlingSide.king ? path : null,
      blackPathQueenSide:
          side == Side.black && cs == CastlingSide.queen ? path : null,
      blackPathKingSide:
          side == Side.black && cs == CastlingSide.king ? path : null,
    );
  }

  Castles _copyWith({
    IraSquareSet? unmovedRooks,
    Box<Square?>? whiteRookQueenSide,
    Box<Square?>? whiteRookKingSide,
    Box<Square?>? blackRookQueenSide,
    Box<Square?>? blackRookKingSide,
    IraSquareSet? whitePathQueenSide,
    IraSquareSet? whitePathKingSide,
    IraSquareSet? blackPathQueenSide,
    IraSquareSet? blackPathKingSide,
  }) {
    return Castles(
      unmovedRooks: unmovedRooks ?? this.unmovedRooks,
      whiteRookQueenSide: whiteRookQueenSide != null
          ? whiteRookQueenSide.value
          : _whiteRookQueenSide,
      whiteRookKingSide: whiteRookKingSide != null
          ? whiteRookKingSide.value
          : _whiteRookKingSide,
      blackRookQueenSide: blackRookQueenSide != null
          ? blackRookQueenSide.value
          : _blackRookQueenSide,
      blackRookKingSide: blackRookKingSide != null
          ? blackRookKingSide.value
          : _blackRookKingSide,
      whitePathQueenSide: whitePathQueenSide ?? _whitePathQueenSide,
      whitePathKingSide: whitePathKingSide ?? _whitePathKingSide,
      blackPathQueenSide: blackPathQueenSide ?? _blackPathQueenSide,
      blackPathKingSide: blackPathKingSide ?? _blackPathKingSide,
    );
  }

  @override
  String toString() {
    return 'Castles(unmovedRooks: $unmovedRooks)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Castles &&
          other.unmovedRooks == unmovedRooks &&
          other._whiteRookQueenSide == _whiteRookQueenSide &&
          other._whiteRookKingSide == _whiteRookKingSide &&
          other._blackRookQueenSide == _blackRookQueenSide &&
          other._blackRookKingSide == _blackRookKingSide &&
          other._whitePathQueenSide == _whitePathQueenSide &&
          other._whitePathKingSide == _whitePathKingSide &&
          other._blackPathQueenSide == _blackPathQueenSide &&
          other._blackPathKingSide == _blackPathKingSide;

  @override
  int get hashCode => Object.hash(
      unmovedRooks,
      _whiteRookQueenSide,
      _whiteRookKingSide,
      _blackRookQueenSide,
      _blackRookKingSide,
      _whitePathQueenSide,
      _whitePathKingSide,
      _blackPathQueenSide,
      _blackPathKingSide);
}

@immutable
class _Context {
  const _Context({
    required this.king,
    required this.blockers,
    required this.checkers,
    required this.mustCapture,
  });

  final bool mustCapture;
  final Square? king;
  final IraSquareSet blockers;
  final IraSquareSet checkers;

  _Context copyWith({
    bool? mustCapture,
    Square? king,
    IraSquareSet? blockers,
    IraSquareSet? checkers,
  }) {
    return _Context(
      mustCapture: mustCapture ?? this.mustCapture,
      king: king,
      blockers: blockers ?? this.blockers,
      checkers: checkers ?? this.checkers,
    );
  }
}

Square _rookCastlesTo(Side side, CastlingSide cs) {
  return side == Side.white
      ? (cs == CastlingSide.queen ? Squares.d1 : Squares.f1)
      : cs == CastlingSide.queen
          ? Squares.d8
          : Squares.f8;
}

Square _kingCastlesTo(Side side, CastlingSide cs) {
  return side == Side.white
      ? (cs == CastlingSide.queen ? Squares.c1 : Squares.g1)
      : cs == CastlingSide.queen
          ? Squares.c8
          : Squares.g8;
}

Square? _validEpSquare(Setup setup) {
  if (setup.epSquare == null) return null;
  final epRank = setup.turn == Side.white ? 5 : 2;
  final forward = setup.turn == Side.white ? 8 : -8;
  if (squareRank(setup.epSquare!) != epRank) return null;
  if (setup.board.occupied.has(setup.epSquare! + forward)) return null;
  final pawn = setup.epSquare! - forward;
  if (!setup.board.pawns.has(pawn) ||
      !setup.board.bySide(setup.turn.opposite).has(pawn)) {
    return null;
  }
  return setup.epSquare;
}
