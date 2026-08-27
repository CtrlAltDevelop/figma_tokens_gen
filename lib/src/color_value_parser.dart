/// Resolves the many shapes a colour can take in an exported Figma token file
/// into a single 32-bit ARGB integer.
///
/// Figma plugins are not consistent here: Tokens Studio writes `"#RRGGBB"`
/// strings, the native Variables export writes `{"hex": "..."}`, and some
/// pipelines emit `{"r": 0..1, "g": .., "b": .., "a": ..}`. All three are
/// accepted so a design team is not forced to change their export settings.
abstract final class ColorValueParser {
  static final RegExp _hexPattern = RegExp(r'^[0-9A-Fa-f]+$');

  /// Returns the ARGB value for [value], or `null` when it is not a colour.
  static int? parse(Object? value) {
    if (value is String) return _fromHexString(value);
    if (value is Map) return _fromMap(value);
    return null;
  }

  static int? _fromMap(Map<Object?, Object?> map) {
    final hex = map['hex'];
    if (hex is String) {
      final parsed = _fromHexString(hex);
      if (parsed != null) return _applyChannelAlpha(parsed, map['a']);
    }

    final r = _channel(map['r']);
    final g = _channel(map['g']);
    final b = _channel(map['b']);
    if (r == null || g == null || b == null) return null;
    final a = _channel(map['a'], fallback: 255)!;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Accepts `#RGB`, `#RGBA`, `#RRGGBB` and `#RRGGBBAA`, with or without the
  /// leading `#`. Figma writes trailing alpha; Dart wants it leading.
  static int? _fromHexString(String source) {
    final trimmed = source.trim();
    // Only a leading `#` is a prefix; one in the middle means this is not a
    // colour at all, and stripping it would accept `1#23456` as `123456`.
    final cleaned = (trimmed.startsWith('#') ? trimmed.substring(1) : trimmed)
        .toUpperCase();
    if (cleaned.isEmpty || !_hexPattern.hasMatch(cleaned)) return null;

    final expanded = switch (cleaned.length) {
      3 || 4 => cleaned.split('').map((c) => '$c$c').join(),
      6 || 8 => cleaned,
      _ => null,
    };
    if (expanded == null) return null;

    if (expanded.length == 6) return int.parse('FF$expanded', radix: 16);

    // RRGGBBAA -> AARRGGBB
    final rgb = expanded.substring(0, 6);
    final alpha = expanded.substring(6, 8);
    return int.parse('$alpha$rgb', radix: 16);
  }

  /// Overlays a separate `a` field onto an already-parsed hex value, which
  /// some exports use instead of an 8-digit hex.
  static int _applyChannelAlpha(int argb, Object? alpha) {
    final parsed = _channel(alpha);
    if (parsed == null) return argb;
    return (parsed << 24) | (argb & 0x00FFFFFF);
  }

  /// Normalises a channel that may be expressed as 0..1 or 0..255.
  ///
  /// Returns [fallback] when [value] is not a number at all, so a caller can
  /// distinguish "absent" from "present but unparseable" by passing `null`.
  static int? _channel(Object? value, {int? fallback}) {
    final number = switch (value) {
      final num n => n,
      final String s => num.tryParse(s),
      _ => null,
    };
    if (number == null) return fallback;
    // A value of exactly 1 is ambiguous; Figma's float form is by far the
    // more common producer of it, so treat <= 1 as normalised.
    final scaled = number <= 1 ? (number * 255).round() : number.round();
    return scaled.clamp(0, 255);
  }
}
