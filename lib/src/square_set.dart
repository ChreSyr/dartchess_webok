import 'package:meta/meta.dart';
import './models.dart';

final _max = BigInt.parse('0xffffffffffffffff');
final _flip1 = BigInt.parse('0x00FF00FF00FF00FF');
final _flip2 = BigInt.parse('0x0000FFFF0000FFFF');
final _mirror1 = BigInt.parse('0x5555555555555555');
final _mirror2 = BigInt.parse('0x3333333333333333');
final _mirror4 = BigInt.parse('0x0f0f0f0f0f0f0f0f');
final _fileA = BigInt.parse('0x0101010101010101');
final _rank8 = BigInt.parse('0xff00000000000000');

/// A set of squares represented by a 64 bit integer mask, using little endian
/// rank-file (LERF) mapping.
///
/// ```
///  9 | 72 73 74 75 76 77 78 79
///  8 | 64 65 66 67 68 69 70 71
///  7 | 56 57 58 59 60 61 62 63
///  6 | 48 49 50 51 52 53 54 55
///  5 | 40 41 42 43 44 45 46 47
///  4 | 32 33 34 35 36 37 38 39
///  3 | 24 25 26 27 28 29 30 31
///  2 | 16 17 18 19 20 21 22 23
///  1 | 8  9  10 11 12 13 14 15
///  0 | 0  1  2  3  4  5  6  7
///    -------------------------
///      a  b  c  d  e  f  g  h
/// ```
@immutable
class SquareSet {
  /// Creates a [SquareSet] with the provided 64bit integer value.
  SquareSet(this.value) : assert(value <= _max);

  /// Creates a [SquareSet] with a single [Square].
  SquareSet.fromSquare(Square square)
      : value = BigInt.one << square,
        assert(square >= 0 && square < 64);

  /// Creates a [SquareSet] from several [Square]s.
  SquareSet.fromSquares(Iterable<Square> squares)
      : value = squares
            .map((square) => BigInt.one << square)
            .fold(BigInt.zero, (left, right) => left | right);

  /// Create a [SquareSet] containing all squares of the given rank.
  SquareSet.fromRank(int rank)
      : value = BigInt.from(0xff) << (8 * rank),
        assert(rank >= 0 && rank < 8);

  /// Create a [SquareSet] containing all squares of the given file.
  SquareSet.fromFile(int file)
      : value = _fileA << file,
        assert(file >= 0 && file < 8);

  /// Create a [SquareSet] containing all squares of the given backrank [Side].
  SquareSet.backrankOf(Side side)
      : value = side == Side.white ? BigInt.from(0xff) : _rank8;

  /// 64 bit integer representing the square set.
  final BigInt value;

  static final empty = SquareSet(BigInt.zero);
  static final full = SquareSet(_max);
  static final lightSquares = SquareSet(BigInt.parse('0x55AA55AA55AA55AA'));
  static final darkSquares = SquareSet(BigInt.parse('0xAA55AA55AA55AA55'));
  static final diagonal = SquareSet(BigInt.parse('0x8040201008040201'));
  static final antidiagonal = SquareSet(BigInt.parse('0x0102040810204080'));
  static final corners = SquareSet(BigInt.parse('0x8100000000000081'));
  static final center = SquareSet(BigInt.parse('0x0000001818000000'));
  static final backranks = SquareSet(BigInt.parse('0xff000000000000ff'));

  /// Bitwise right shift
  SquareSet shr(int shift) {
    if (shift >= 64) return SquareSet.empty;
    if (shift > 0) return SquareSet(value >> shift);
    return this;
  }

  /// Bitwise left shift
  SquareSet shl(int shift) {
    if (shift >= 64) return SquareSet.empty;
    if (shift > 0) return SquareSet(value << shift & _max);
    return this;
  }

  SquareSet xor(SquareSet other) => SquareSet(value ^ other.value);
  SquareSet operator ^(SquareSet other) => SquareSet(value ^ other.value);

  SquareSet union(SquareSet other) => SquareSet(value | other.value);
  SquareSet operator |(SquareSet other) => SquareSet(value | other.value);

  SquareSet intersect(SquareSet other) => SquareSet(value & other.value);
  SquareSet operator &(SquareSet other) => SquareSet(value & other.value);

  SquareSet minus(SquareSet other) => SquareSet(value - other.value);
  SquareSet operator -(SquareSet other) => SquareSet(value - other.value);

  SquareSet complement() => SquareSet(~value);

  SquareSet diff(SquareSet other) => SquareSet(value & ~other.value);

  SquareSet flipVertical() {
    BigInt x = ((value >> 8) & _flip1) | ((value & _flip1) << 8);
    x = ((x >> 16) & _flip2) | ((x & _flip2) << 16);
    x = (x >> 32) | (x << 32) & _max;
    return SquareSet(x);
  }

  SquareSet mirrorHorizontal() {
    BigInt x = ((value >> 1) & _mirror1) | ((value & _mirror1) << 1);
    x = ((x >> 2) & _mirror2) | ((x & _mirror2) << 2);
    x = ((x >> 4) & _mirror4) | ((x & _mirror4) << 4);
    return SquareSet(x);
  }

  int get size => _nsbBigInt(value);
  bool get isEmpty => value == BigInt.zero;
  bool get isNotEmpty => value != BigInt.zero;
  int? get first => _getFirstSquare(value);
  int? get last => _getLastSquare(value);
  Iterable<Square> get squares => _iterateSquares();
  Iterable<Square> get squaresReversed => squares.toList().reversed;
  bool get moreThanOne => isNotEmpty && size > 1;

  /// Returns square if it is single, otherwise returns null.
  int? get singleSquare => moreThanOne ? null : last;

  bool has(Square square) {
    assert(square >= 0 && square < 64);
    return value & (BigInt.one << square) != BigInt.zero;
  }

  bool isIntersected(SquareSet other) => intersect(other).isNotEmpty;
  bool isDisjoint(SquareSet other) => intersect(other).isEmpty;

  SquareSet withSquare(Square square) {
    assert(square >= 0 && square < 64);
    return SquareSet(value | (BigInt.one << square));
  }

  SquareSet withoutSquare(Square square) {
    assert(square >= 0 && square < 64);
    return SquareSet(value & ~(BigInt.one << square));
  }

  /// Removes [Square] if present, or put it if absent.
  SquareSet toggleSquare(Square square) {
    assert(square >= 0 && square < 64);
    return SquareSet(value ^ (BigInt.one << square));
  }

  SquareSet withoutFirst() {
    final f = first;
    return f != null ? withoutSquare(f) : empty;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SquareSet &&
            other.runtimeType == runtimeType &&
            other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    final buffer = StringBuffer();
    for (Square square = 63; square >= 0; square--) {
      buffer.write(has(square) ? '1' : '0');
    }
    final b = buffer.toString();
    final first = int.parse(b.substring(0, 32), radix: 2)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
    final last = int.parse(b.substring(32, 64), radix: 2)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
    final stringVal = '$first$last';
    if (stringVal == '0000000000000000') {
      return 'SquareSet(0)';
    }
    return 'SquareSet(0x$first$last)';
  }

  Iterable<Square> _iterateSquares() sync* {
    BigInt bitboard = value;
    while (bitboard != BigInt.zero) {
      final square = _getFirstSquare(bitboard);
      bitboard ^= BigInt.one << square!;
      yield square;
    }
  }

  /// Return the position of the lowest bit
  int? _getFirstSquare(BigInt bitboard) {
    final ntz = _ntzBigInt(bitboard);
    return ntz >= 0 && ntz < 64 ? ntz : null;
  }

  /// Return the position of the highest bit
  int? _getLastSquare(BigInt bitboard) {
    if (bitboard == BigInt.zero) return null;

    int lastSquare = 0;
    var bigInt = bitboard;
    while (bigInt > BigInt.one) {
      bigInt >>= 1;
      lastSquare++;
    }

    return lastSquare;
  }
}

/// Return the Number of Set Bits in a BigInt
int _nsbBigInt(BigInt bigInt) {
  int count = 0;

  var big = bigInt;
  while (big > BigInt.zero) {
    if (big & BigInt.one == BigInt.one) {
      count++;
    }

    big >>= 1;
  }

  return count;
}

/// Return the Number of Trailing Zeros in a BigInt
int _ntzBigInt(BigInt bigInt) {
  if (bigInt == BigInt.zero) {
    return -1;
  }

  int count = 0;
  var big = bigInt;
  while (big & BigInt.one == BigInt.zero) {
    big >>= 1;
    count++;
  }

  return count;
}
