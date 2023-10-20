A web-friendly variant of the package 'dartchess' from lichess.

dartchess github : https://github.com/lichess-org/dartchess

## Features

- dartchess features
- web supported

## Example

```dart
import 'package:dartchess_webok/dartchess_webok.dart';

final pos = Chess.fromSetup(IraSetup.parseFen('fd(0)s(0)yys(1)d(1)g/rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR/FD(2)S(2)YYS(3)D(3)G w QKqk - 1100000000000000-0000000000000001 1 3'));
assert(pos.isCheckmate == true);
```
