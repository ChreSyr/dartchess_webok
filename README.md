A web-friendly variant of the package 'dartchess' from lichess.

dartchess github : https://github.com/lichess-org/dartchess

## Features

- dartchess features
- web supported

## Example

```dart
import 'package:dartchess_webok/dartchess_webok.dart';

final pos = Chess.fromSetup(Setup.parseFen('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w QKqk - 1 3'));
assert(pos.isCheckmate == true);
```
