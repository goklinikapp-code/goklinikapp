import 'dart:convert';

const _mojibakeMarkers = ['Ã', 'Â', 'ð', '�'];
const _cp1252UnicodeToByte = <int, int>{
  0x20AC: 0x80,
  0x201A: 0x82,
  0x0192: 0x83,
  0x201E: 0x84,
  0x2026: 0x85,
  0x2020: 0x86,
  0x2021: 0x87,
  0x02C6: 0x88,
  0x2030: 0x89,
  0x0160: 0x8A,
  0x2039: 0x8B,
  0x0152: 0x8C,
  0x017D: 0x8E,
  0x2018: 0x91,
  0x2019: 0x92,
  0x201C: 0x93,
  0x201D: 0x94,
  0x2022: 0x95,
  0x2013: 0x96,
  0x2014: 0x97,
  0x02DC: 0x98,
  0x2122: 0x99,
  0x0161: 0x9A,
  0x203A: 0x9B,
  0x0153: 0x9C,
  0x017E: 0x9E,
  0x0178: 0x9F,
};

String normalizeApiText(dynamic value) {
  final raw = (value ?? '').toString();
  if (raw.isEmpty) return '';

  final repaired = _repairCommonUtf8Mojibake(raw);
  return repaired.replaceAll('\u0000', '');
}

String _repairCommonUtf8Mojibake(String input) {
  if (!_looksMojibake(input)) return input;

  try {
    final bytes = _encodeAsSingleByte(input);
    if (bytes == null) return input;
    final repaired = utf8.decode(
      bytes,
      allowMalformed: true,
    );
    if (_markerScore(repaired) <= _markerScore(input)) {
      return repaired;
    }
  } catch (_) {
    // Keep original when content cannot be repaired safely.
  }

  return input;
}

List<int>? _encodeAsSingleByte(String input) {
  final bytes = <int>[];
  for (final codeUnit in input.codeUnits) {
    if (codeUnit <= 0xFF) {
      bytes.add(codeUnit);
      continue;
    }

    final cp1252Byte = _cp1252UnicodeToByte[codeUnit];
    if (cp1252Byte == null) return null;
    bytes.add(cp1252Byte);
  }
  return bytes;
}

bool _looksMojibake(String input) {
  for (final marker in _mojibakeMarkers) {
    if (input.contains(marker)) return true;
  }
  return false;
}

int _markerScore(String input) {
  var score = 0;
  for (final marker in _mojibakeMarkers) {
    score += marker.allMatches(input).length;
  }
  return score;
}
