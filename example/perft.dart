import 'package:dartchess_webok/dartchess_webok.dart';

void main() {
  final stopwatch = Stopwatch()..start();
  const depth = 4;
  perft(Chess.initial, depth);
  print(
      'initial position perft at depht $depth executed in ${stopwatch.elapsed.inMilliseconds} ms');
}
