# Changelog

## 1.1.2

### Fixed

- **Non-colour tokens were emitted as colours.** A bare hex string is accepted
  without its `#`, so any 3-, 4-, 6- or 8-character value made of hex digits
  parsed as a colour: a font weight of `"700"` became `#770000`, a font size of
  `"1234"` became `#11223344`, and a spacing of `"128"` became `#112288`, each
  landing in the generated file as a `Color`. Tokens Studio writes those values
  as strings. A token that declares a type other than `color` — `$type` or
  `type`, on the token or inherited from a group, and along an alias chain — is
  now left out. A token with no declared type behaves as before.
- **`alpha` on a W3C colour object was ignored.** Figma's variable export writes
  a translucent colour as `{"hex": "#3366CC", "alpha": 0.5, …}`, and the alpha
  was dropped, generating the colour fully opaque. `alpha` is now applied, and
  an sRGB `components` list is read when there is no `hex`.
- **`$themes.json` failed the whole run.** Tokens Studio writes it next to the
  token sets as an array, which is not a token document, so a directory export
  stopped with "Expected a JSON object at the root". It and `$metadata.json`
  are now skipped when reading a directory.
- **A colour at the document root vanished without a warning**, though the
  warning for a root-level token was written for exactly this. A root string
  that is a `#` hex or an alias is now reported.
- **The generated palette class could fail to compile.** Two categories that
  camel-case alike (`Primary` and `primary`) emitted two fields of one name,
  and a category or token whose name holds no letters or digits emitted an
  empty identifier. Fields are now numbered on collision, with a comment, the
  way members already were, and an empty name falls back to `category` or
  `color`.

## 1.1.1

- No change to the published code. CI moved to the shared reusable workflow in
  CtrlAltDevelop/ci-workflows: formatting, `analyze --fatal-infos`, the tests,
  the example, a changelog entry per version, and a pana score with no points
  lost — the same gate across every package here.
- Dependency bounds are explicit ranges rather than carets — a floor that
  resolves on the supported SDK, the next major as the ceiling — so a consumer
  already on an older version in the same major is not forced to move.
- The README carries the pub, pub points, CI and licence badges the other
  packages here carry.

## 1.1.0

### Added

- **Nested token groups**, to any depth. Figma's native Variables export writes
  `color/brand/primary` as three levels of object, and every token below the
  second level was previously dropped without a word — a grouped export
  generated an empty file and the "found no colour tokens" error. The top-level
  key stays the category and the rest becomes the token name, so the member is
  `colorBrandPrimary` and the palette key `brandPrimary`. A flat export is
  unaffected.
- **Alias resolution.** A `{group.token}` value is followed to the token it
  names, which is how a semantic layer points at a primitive one. References
  resolve after all input files are merged, so the target may live in another
  file — the way Tokens Studio splits primitives from semantics. Chains and
  `/`-separated paths work; `TokenParser(resolveAliases: false)` restores the
  old behaviour of treating a reference as an unparseable value.
- **Warnings** for tokens that were understood but skipped: an alias naming
  nothing, an alias cycle, an alias pointing at a group, a token sitting at the
  root outside any category. Previously all of these vanished silently, so a
  typo'd reference looked like a token the designer had never added. Exposed as
  `TokenSet.warnings` / `ConversionResult.warnings`, printed to stderr by the
  CLI even under `--quiet`, and included in the error when nothing generates.
- `--strict`, which exits non-zero if anything was skipped. Intended for CI, so
  a broken reference fails the build instead of quietly shrinking the output.
- `TokenParser.parseDocuments` and `TokenParser.documentOf`, for interpreting
  several documents as one set. `parseDocuments` deep-merges the raw documents
  before resolving, so nested groups combine per key instead of the whole group
  being replaced. `categoriesOf` and `merge` still work, but resolve each
  document alone and so cannot follow an alias across files.

### Fixed

- Colliding member names are now made unique. Flattening nested groups makes
  the collision reachable — `brand/primary` and `brandPrimary` under one
  category both want `colorBrandPrimary` — and two members of one name, or two
  identical keys in a `const` map literal, do not compile. The second gets a
  numeric suffix and a comment in the generated file recording the rename.
- A hex string with a `#` anywhere but the front is no longer accepted: every
  `#` was stripped, so `1#23456` parsed as the colour `123456`.
- A `--material-import` containing a quote, backslash or newline no longer
  breaks the generated import line.

### Changed

- Dropped the meaningless `unused_field` entry from the generated file's
  `ignore_for_file` comment.
- The CLI version is now pinned to `pubspec.yaml` by a test, after it drifted
  in 1.0.0.

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
