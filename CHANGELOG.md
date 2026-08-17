# Changelog

## 1.0.0

Targets Dart 3.13 / Flutter 3.47.

### Breaking

- Generated files now import `package:material_ui/material_ui.dart` instead of
  `package:flutter/material.dart`, following the Material widgets moving into
  their own package in Flutter 3.47. Add `material_ui` to the dependencies of
  the project you generate into. Teams still on `package:flutter/material.dart`
  can pass `--material-import package:flutter/material.dart`, or set
  `DartColorsEmitter.materialImport` — see `legacyMaterialImport`.
- The SDK lower bound is now `^3.13.0`.

### Fixed

- Generated palette maps failed to compile when a token name starts with a
  digit: keys are strings, but they were run through the Dart *identifier*
  escaping, so a `500` token emitted `'$500'` — which Dart reads as string
  interpolation. Palette keys now keep the token name as authored, and any `$`,
  `'` or `\` in a name is escaped for the string literal. Numeric scale tokens
  (`gray/500`) are common in Figma exports, so this hit real token sets.
  Constant names are unaffected.
- `--version` reported `0.1.0` regardless of the released version.

### Changed

- Bumped `lints` to `^6.1.0` and the remaining dependencies to current, and
  reformatted with the Dart 3.13 formatter.
- Verified end to end on Flutter 3.47: the generated output analyzes clean with
  `deprecated_member_use` promoted to an error, and works as `ColorScheme` and
  `ThemeData` input in a widget test.

## 0.1.1

- Fixed acronym tokens being mangled: `Naming.words` lower-cased every part, so
  a `BG` token under `background` emitted `backgroundBg` instead of
  `backgroundBG`. Word parts now keep their authored case, and only
  `toSnakeCase` and the leading word of `toLowerCamelCase` lower-case
  explicitly.

## 0.1.0

Initial release.

- CLI (`dart run figma_tokens_gen`) with configurable input, output, class
  names, file name and palette emission.
- Parses DTCG (`$value`), legacy (`value`) and bare token value shapes.
- Accepts `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, `{"hex": …}` with optional
  `a`, and `{"r","g","b","a"}` channels in 0–1 or 0–255 form.
- Merges multiple token files in sorted path order for deterministic output.
- Skips non-colour tokens and plugin metadata keys.
- Escapes Dart reserved words and identifiers starting with a digit.
- Generated output carries no timestamp, so unchanged tokens produce no diff.
- Library API — `TokenParser`, `DartColorsEmitter`, `TokenConverter` — with a
  `TokenEmitter` interface for custom back-ends.
