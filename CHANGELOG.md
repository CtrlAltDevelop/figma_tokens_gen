# Changelog

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
