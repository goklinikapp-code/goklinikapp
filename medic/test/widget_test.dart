import 'package:flutter_test/flutter_test.dart';

import 'package:goklinik_medic/core/theme/app_theme.dart';

void main() {
  test('goklinik medic theme exposes brand colors', () {
    expect(GKColors.primary.toARGB32(), 0xFF4A7C59);
    expect(GKColors.secondary.toARGB32(), 0xFF1B5E73);
    expect(GKColors.accent.toARGB32(), 0xFFC8992E);
  });
}
