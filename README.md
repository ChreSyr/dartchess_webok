Iratus rules written in dart for native platforms (does not support web).

## Features

- Completely immutable Position class
- Read and write FEN
- Read and write SAN
- Iratus rules:
  - move making
  - legal moves generation
  - game end and outcome
  - insufficient material
  - setup validation
- PGN parser and writer
- Bitboards
- Attacks and rays using hyperbola quintessence

## Example

```dart
import 'package:dartiratus/dartiratus.dart';

final pos = Iratus.fromSetup(IraSetup.parseFen('fd(0)s(0)yys(1)d(1)g/rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR/FD(2)S(2)YYS(3)D(3)G w QKqk - 1100000000000000-0000000000000001 1 3'));
assert(pos.isCheckmate == true);
```

## Additional information

This package was HEAVILY inspired from:

- https://github.com/lichess-org/dartchess
