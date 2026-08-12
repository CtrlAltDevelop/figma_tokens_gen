# figma_tokens_gen

Generate Flutter `Color` constants and palette maps from Figma design-token
JSON exports.

Point it at the JSON your design team exports, and get a checked-in Dart file
with one `static const Color` per token — no runtime parsing, no asset lookup,
no string keys in your widget code.

```dart
Container(color: AppColors.primaryMain);
```

## Install

As a dev dependency in the project you want to generate into:

```bash
dart pub add --dev figma_tokens_gen
```

Or globally, to use it across projects:

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
| `--no-palettes` | _(palettes on)_ | Skip the `Map<String, Color>` class |
| `-q, --quiet` | off | Suppress progress output |

## Input

Every top-level object is a **category**; every object inside it is a **token**.
Three value shapes are accepted, so you should not have to change your export
settings:

```json
{
  "primary": {
    "main":       { "$value": { "hex": "#3B5BFF" }, "$type": "color" },
    "light":      { "$value": "#8FA3FF" },
    "extraLight": "#E4E9FF"
  }
}
```

- **DTCG** — `{"$value": ...}` (Tokens Studio, the W3C draft format)
- **Legacy** — `{"value": ...}`
- **Bare** — the value directly

Colour values may be `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, a `{"hex": ...}`
map with an optional `a` field, or `{"r":…, "g":…, "b":…, "a":…}` channels in
either 0–1 or 0–255 form.

Non-colour tokens (spacing, typography) and plugin metadata keys (`$extensions`,
`$themes`, `$metadata`) are skipped.

## Output

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';

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
get a trailing underscore; names starting with a digit get a `$` prefix.

The output contains **no timestamp**, so re-running the generator with unchanged
tokens produces no diff.

## Multiple files

When `--input` is a directory, every `.json` file under it is read in sorted
path order and merged. Categories combine; a token declared twice is taken from
the file that sorts last. Sorting is what makes the merge deterministic across
machines and CI.

## Library API

Every stage is separately usable when the CLI is not enough — for example to
fetch tokens over HTTP, or to emit a different shape of code:

```dart
import 'package:figma_tokens_gen/figma_tokens_gen.dart';

// Parse without touching the filesystem.
final tokens = const TokenParser().parseJson(jsonString);
print('${tokens.colorCount} colours in ${tokens.categories.length} categories');

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
dart run figma_tokens_gen -i tokens -o lib/generated/theme -q
dart format lib/generated/theme
```

Commit the generated file. Checking it in keeps builds reproducible and makes
token changes visible in review.

## License

MIT
