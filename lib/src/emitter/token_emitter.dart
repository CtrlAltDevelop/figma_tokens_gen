import '../models/color_token.dart';

/// Renders a parsed [TokenSet] into source code.
///
/// An interface rather than a function so alternative back-ends (a
/// `ThemeExtension` emitter, a CSS-variables emitter, a Compose emitter) can be
/// added without touching the parser or the CLI.
abstract interface class TokenEmitter {
  /// The file name this emitter writes, relative to the output directory.
  String get fileName;

  /// Renders [tokens] to source text.
  String emit(TokenSet tokens);
}
