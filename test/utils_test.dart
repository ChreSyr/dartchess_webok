
import 'package:dartiratus/dartiratus.dart';
import 'package:test/test.dart';

void main() {
  test('algebraicLegalMoves with Kh8', () {
    final setup = Setup.parseFen(
        'r1bq1r2/3n2k1/p1p1pp2/3pP2P/8/PPNB2Q1/2P2P2/R3K3 b Q - 1 22');
    final pos = Iratus.fromSetup(setup);
    final moves = algebraicLegalMoves(pos);
    expect(moves['g7'], contains('h8'));
    expect(moves['g7'], isNot(contains('g8')));
  });

  test('algebraicLegalMoves with castle', () {
    final wtm = Iratus.fromSetup(
        Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'));
    expect(algebraicLegalMoves(wtm)['e1'],
        equals({'a1', 'c1', 'd1', 'd2', 'e2', 'f1', 'f2', 'g1', 'h1'}));
    expect(algebraicLegalMoves(wtm)['e8'], null);

    final btm = Iratus.fromSetup(
        Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1'));
    expect(algebraicLegalMoves(btm)['e8'],
        equals({'a8', 'c8', 'd7', 'd8', 'e7', 'f7', 'f8', 'g8', 'h8'}));
    expect(algebraicLegalMoves(btm)['e1'], null);
  });
}
