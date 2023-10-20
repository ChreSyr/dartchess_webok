int getHighestBitPosition(BigInt bigInt) {
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

void main() {
  for (final str in [
    '010000',
    '00111000',
    '000111100',
    '000010',
    '0010001',
  ]) {
    final num = BigInt.parse(str, radix: 2);

    final trailingZeros = getHighestBitPosition(num);

    print('$num, Big pos : $trailingZeros');
  }
  test();
}

void test() {
  const numSamples = 1000; // Number of samples to test

  final samples = List.generate(numSamples, (index) {
    return BigInt.one << index;
  });

  final stopwatch = Stopwatch()..start();

  for (final sample in samples) {
    getHighestBitPosition(sample);
  }

  final elapsed = stopwatch.elapsedMilliseconds;

  print('1 Tested $numSamples samples in $elapsed ms');
}
