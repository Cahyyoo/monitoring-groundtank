import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/services/format.dart';

void main() {
  test('cmPrecise always shows one decimal, with a comma', () {
    expect(Format.cmPrecise(109.8), '109,8 cm');
    expect(Format.cmPrecise(110), '110,0 cm');
    expect(Format.cmPrecise(109.84), '109,8 cm');
    expect(Format.cmPrecise(1234.5), '1.234,5 cm');
  });

  test('cmCompact shows a decimal only when there is one', () {
    expect(Format.cmCompact(180), '180 cm');
    expect(Format.cmCompact(180.5), '180,5 cm');
  });
}
