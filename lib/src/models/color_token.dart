import 'package:meta/meta.dart';

/// A single design token resolved to a concrete ARGB colour.
@immutable
class ColorToken {
  const ColorToken({
    required this.name,
    required this.argb,
  });

  /// The token name exactly as authored in Figma (for example `extraLight`).
  final String name;

  /// The fully opaque-or-transparent 32-bit ARGB value.
  final int argb;

  /// The value formatted as a Dart integer literal, e.g. `0xFF1A2B3C`.
  String get hexLiteral =>
      '0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ColorToken && other.name == name && other.argb == argb;

  @override
  int get hashCode => Object.hash(name, argb);

  @override
  String toString() => 'ColorToken($name, $hexLiteral)';
}

/// A named group of [ColorToken]s, corresponding to a top-level key in the
/// exported Figma JSON (for example `primary`, `background`, `text`).
@immutable
class TokenCategory {
  const TokenCategory({required this.name, required this.tokens});

  /// The category name exactly as authored in Figma.
  final String name;

  final List<ColorToken> tokens;

  bool get isEmpty => tokens.isEmpty;
  bool get isNotEmpty => tokens.isNotEmpty;

  @override
  String toString() => 'TokenCategory($name, ${tokens.length} tokens)';
}

/// The complete result of parsing one or more Figma token files.
@immutable
class TokenSet {
  const TokenSet(this.categories);

  final List<TokenCategory> categories;

  /// Total number of colour tokens across every category.
  int get colorCount =>
      categories.fold(0, (sum, category) => sum + category.tokens.length);

  bool get isEmpty => categories.every((category) => category.isEmpty);
}
