# figma_tokens_gen

[![pub package](https://img.shields.io/pub/v/figma_tokens_gen.svg)](https://pub.dev/packages/figma_tokens_gen)
[![pub points](https://img.shields.io/pub/points/figma_tokens_gen)](https://pub.dev/packages/figma_tokens_gen/score)
[![CI](https://github.com/CtrlAltDevelop/figma_tokens_gen/actions/workflows/ci.yml/badge.svg)](https://github.com/CtrlAltDevelop/figma_tokens_gen/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/CtrlAltDevelop/figma_tokens_gen/blob/main/LICENSE)

Generate Flutter `Color` constants and palette maps from Figma design-token
JSON exports.

Point it at the JSON your design team exports, and get a checked-in Dart file
with one `static const Color` per token — no runtime parsing, no asset lookup,
no string keys in your widget code.

```dart
Container(color: AppColors.primaryMain);
```

## Requirements

| | Version |
| --- | --- |
| Dart SDK | 3.12.0 or newer |
| Flutter (for the generated code) | 3.44.0 or newer |

Flutter 3.44 moved the Material widgets into their own
[`material_ui`](https://pub.dev/packages/material_ui) package, so that is what
the generated file imports:

```yaml
dependencies:
  material_ui: ">=1.0.0 <2.0.0"
```

On a project still importing `package:flutter/material.dart`, pass
`--material-import package:flutter/material.dart` and the generated file will
use the old import instead. The generator itself is pure Dart and depends on
neither.

## Install

As a dev dependency in the project you want to generate into:

```bash
dart pub add --dev figma_tokens_gen
```

Or add it to `pubspec.yaml` yourself. It is a build-time tool, so it belongs in
`dev_dependencies` — it never ships in your app:

```yaml
dev_dependencies:
  figma_tokens_gen: ">=1.1.1 <2.0.0"
```

then:

```bash
dart pub get      # or: flutter pub get
```

Or install it globally, to use across projects without adding a dependency:

```bash
dart pub global activate figma_tokens_gen
```

## Use

```bash
dart run figma_tokens_gen --input tokens --output lib/generated/theme
```

| Option | Default | Meaning |
| --- | --- | --- |
| `-i, --input` | `tokens` | Directory (searched recursively) or a single JSON file |
| `-o, --output` | `lib/generated/theme` | Directory the generated file is written to |
| `--class-name` | `AppColors` | Name of the constants class |
| `--palette-class-name` | `AppColorPalette` | Name of the palette-map class |
| `--file-name` | `app_colors.dart` | Name of the generated file |
| `--material-import` | `package:material_ui/material_ui.dart` | Import the generated file uses for `Color` |
| `--no-palettes` | _(palettes on)_ | Skip the `Map<String, Color>` class |
| `--strict` | off | Exit non-zero if any token was skipped |
| `-q, --quiet` | off | Suppress progress output (warnings still print) |

## Input

Every top-level object is a **category**; objects inside it are **tokens**, or
further groups of tokens. Three value shapes are accepted, so you should not
have to change your export settings:

```json
{
  "primary": {
    "main":       { "$value": { "hex": "#3B5BFF" }, "$type": "color" },
    "light":      { "$value": "#8FA3FF" },
    "extraLight": "#E4E9FF"
  }
}
```

- **DTCG** — `{"$value": ...}`, the current format: the W3C draft that Figma's
  own variable export and recent Tokens Studio versions write
- **Legacy** — `{"value": ...}`, written by older Figma token plugins
- **Bare** — the value directly

Both the current `$`-prefixed export and older exports work as-is, so upgrading
your Figma plugin does not require changing anything here — and the two shapes
can be mixed within a single file, which is what a partly re-exported token set
looks like in practice.

Colour values may be `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, a `{"hex": ...}`
map with an optional `a` field, or `{"r":…, "g":…, "b":…, "a":…}` channels in
either 0–1 or 0–255 form.

Non-colour tokens (spacing, typography) and plugin metadata keys (`$extensions`,
`$themes`, `$metadata`) are skipped.

### Nested groups

Groups nest to any depth, which is how Figma's own Variables export writes a
name like `color/brand/primary`. The top-level key stays the category and the
rest becomes the token name:

```json
{
  "color": {
    "brand": { "primary": { "$value": "#3B5BFF" } },
    "surface": { "$value": "#F7F8FA" }
  }
}
```

```dart
static const Color colorBrandPrimary = Color(0xFF3B5BFF);
static const Color colorSurface = Color(0xFFF7F8FA);
```

The palette key drops the category the same way it always has, so the token
above is `AppColorPalette.color['brandPrimary']`.

### Aliases

A `{group.token}` value is followed to the token it names — the reference a
semantic layer uses to point at a primitive one:

```json
{
  "primitive": { "blue500": { "$value": "#3B5BFF" } },
  "action":    { "primary": { "$value": "{primitive.blue500}" } }
}
```

Both `AppColors.primitiveBlue500` and `AppColors.actionPrimary` come out as
`Color(0xFF3B5BFF)`. References resolve after every input file is merged, so
the primitive may live in a different file from the token pointing at it —
which is how Tokens Studio splits them. Chains and `/`-separated paths work
too.

A reference that names nothing, or a cycle, is **reported rather than silently
dropped**:

```
Warning: Token "action/primary" references "{primitive.blue600}", which no
token defines. It was skipped.
```

Warnings go to stderr and print even under `--quiet`, because a skipped token
is a token missing from the generated file, not progress noise. The rest of the
tokens still generate; pass `--strict` to make a warning fail the run, which is
what you want in CI. Pass `TokenParser(resolveAliases: false)` to go back to
treating a reference as an ordinary unparseable value.

## Output

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  // primary
  static const Color primaryMain = Color(0xFF3B5BFF);
  static const Color primaryExtraLight = Color(0xFFE4E9FF);
}

/// The same tokens grouped by category, for lookup by name.
abstract final class AppColorPalette {
  /// Tokens under the `primary` category.
  static const Map<String, Color> primary = {
    'main': Color(0xFF3B5BFF),
    'extraLight': Color(0xFFE4E9FF),
  };
}
```

Member names are `category` + `Token` in lowerCamelCase — `primary`/`extraLight`
becomes `primaryExtraLight`. Names that would collide with a Dart reserved word
get a trailing underscore; names starting with a digit get a `$` prefix. Palette
map keys are strings, so they keep the token name as authored — a `500` token is
`AppColorPalette.gray['500']`.

Because nesting is flattened, two tokens can ask for the same name —
`brand/primary` and `brandPrimary` both want `colorBrandPrimary`. The second
one gets a `2` suffix and a comment in the generated file saying so, since two
members of one name (or two identical keys in a `const` map) would not compile.

The output contains **no timestamp**, so re-running the generator with unchanged
tokens produces no diff.

## Multiple files

When `--input` is a directory, every `.json` file under it is read in sorted
path order and merged. Categories and nested groups combine; a token declared
twice is taken from the file that sorts last. Sorting is what makes the merge
deterministic across machines and CI.

The merge happens before aliases are resolved, so a reference can cross files
in either direction — a semantic file may point at primitives that sort after
it.

## Library API

Every stage is separately usable when the CLI is not enough — for example to
fetch tokens over HTTP, or to emit a different shape of code:

```dart
import 'package:figma_tokens_gen/figma_tokens_gen.dart';

// Parse without touching the filesystem.
final tokens = const TokenParser().parseJson(jsonString);
print('${tokens.colorCount} colours in ${tokens.categories.length} categories');
for (final warning in tokens.warnings) print(warning);

// Or several documents at once, so aliases can resolve across them.
const parser = TokenParser();
final merged = parser.parseDocuments([
  parser.documentOf(primitivesJson),
  parser.documentOf(semanticJson),
]);

// Emit with your own class names.
final source = const DartColorsEmitter(className: 'BrandColors').emit(tokens);

// Or run the whole pipeline.
final result = await TokenConverter().convert(
  inputPath: 'tokens',
  outputPath: 'lib/generated/theme',
);
```

To generate something other than a Flutter colour class — a `ThemeExtension`,
CSS variables, Compose tokens — implement `TokenEmitter` and pass it to
`TokenConverter`. The parser and CLI need no changes.

## Wiring it into a build

Add it to whatever runs your codegen, next to `build_runner`:

```bash
dart run figma_tokens_gen -i tokens -o lib/generated/theme -q --strict
dart format lib/generated/theme
```

Commit the generated file. Checking it in keeps builds reproducible and makes
token changes visible in review.

## License

MIT
