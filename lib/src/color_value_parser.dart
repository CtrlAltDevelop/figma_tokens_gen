/// Resolves the many shapes a colour can take in an exported Figma token file
/// into a single 32-bit ARGB integer.
///
/// Figma plugins are not consistent here: Tokens Studio writes `"#RRGGBB"`
/// strings, the native Variables export writes `{"hex": "..."}`, and some
/// pipelines emit `{"r": 0..1, "g": .., "b": .., "a": ..}`. All three are
/// accepted so a design team is not forced to change their export settings.
///
/// The W3C colour object — `{"colorSpace": "srgb", "components": [r, g, b],
/// "alpha": .., "hex": ..}` — is read too. Its `hex` carries no alpha, so
/// `alpha` is applied on top of it; without a `hex`, an sRGB `components` list
/// is used directly. Other colour spaces need a real conversion and are left
/// to their `hex`.
///
/// CSS colour functions — `rgb(…)`, `rgba(…)`, `hsl(…)`, `hsla(…)`, in the
/// comma or the space-and-slash syntax — are read as well; Tokens Studio writes
/// a translucent colour that way.
abstract final class ColorValueParser {
  static final RegExp _hexPattern = RegExp(r'^[0-9A-Fa-f]+$');

  /// Returns the ARGB value for [value], or `null` when it is not a colour.
  static int? parse(Object? value) {
    if (value is String) return _fromHexString(value) ?? _fromFunction(value);
    if (value is Map) return _fromMap(value);
    return null;
  }

  static int? _fromMap(Map<Object?, Object?> map) {
    // `alpha` is the W3C spelling, `a` the older one.
    final alpha = map['alpha'] ?? map['a'];

    final hex = map['hex'];
    if (hex is String) {
      final parsed = _fromHexString(hex);
      if (parsed != null) return _applyChannelAlpha(parsed, alpha);
    }

    final rgb = _rgbChannels(map);
    if (rgb == null) return null;
    final (r, g, b) = rgb;
    final a = _channel(alpha, fallback: 255)!;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// The red, green and blue channels of [map], or `null` if it does not
  /// have all three.
  static (int, int, int)? _rgbChannels(Map<Object?, Object?> map) {
    final components = map['components'];
    if (components is List) {
      if (map['colorSpace'] != 'srgb' || components.length < 3) return null;
      final r = _channel(components[0]);
      final g = _channel(components[1]);
      final b = _channel(components[2]);
      return r == null || g == null || b == null ? null : (r, g, b);
    }

    final r = _channel(map['r']);
    final g = _channel(map['g']);
    final b = _channel(map['b']);
    return r == null || g == null || b == null ? null : (r, g, b);
  }

  static final RegExp _function = RegExp(
    r'^(rgba?|hsla?)\(\s*([^()]*?)\s*\)$',
    caseSensitive: false,
  );
  static final RegExp _functionSeparator = RegExp(r'[\s,/]+');
  static final RegExp _functionArgument = RegExp(
    r'^([+-]?(?:\d+\.?\d*|\.\d+))(%|deg)?$',
  );

  /// `rgb(255, 0, 0)`, `rgba(255 0 0 / 50%)`, `hsl(210, 50%, 40%)`.
  static int? _fromFunction(String source) {
    final match = _function.firstMatch(source.trim());
    if (match == null) return null;
    final args = match[2]!.split(_functionSeparator);
    if (args.length != 3 && args.length != 4) return null;

    final numbers = <(double, String?)>[];
    for (final arg in args) {
      final parsed = _functionArgument.firstMatch(arg);
      if (parsed == null) return null;
      numbers.add((double.parse(parsed[1]!), parsed[2]));
    }

    int alpha = 255;
    if (numbers.length == 4) {
      final (value, unit) = numbers[3];
      alpha = _clamp255((unit == '%' ? value / 100 : value) * 255);
    }

    final int r, g, b;
    if (match[1]!.toLowerCase().startsWith('rgb')) {
      int channel((double, String?) n) =>
          _clamp255(n.$2 == '%' ? n.$1 * 255 / 100 : n.$1);
      r = channel(numbers[0]);
      g = channel(numbers[1]);
      b = channel(numbers[2]);
    } else {
      // Saturation and lightness are percentages whether or not they say so.
      final h = ((numbers[0].$1 % 360) + 360) % 360 / 360;
      final s = (numbers[1].$1 / 100).clamp(0.0, 1.0);
      final l = (numbers[2].$1 / 100).clamp(0.0, 1.0);
      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;
      double hue(double t) {
        t = (t % 1 + 1) % 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
      }

      r = _clamp255(hue(h + 1 / 3) * 255);
      g = _clamp255(hue(h) * 255);
      b = _clamp255(hue(h - 1 / 3) * 255);
    }
    return (alpha << 24) | (r << 16) | (g << 8) | b;
  }

  static int _clamp255(double value) => value.round().clamp(0, 255);

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
