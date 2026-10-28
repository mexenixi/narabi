# Localization / 翻訳

Narabi welcomes reviews of existing translations and proposals for additional languages.
The app supports 21 locales today. The Xcode string catalogs remain the source of truth.

Narabiでは、既存翻訳の見直しと新しい言語の追加提案を歓迎します。現在は21ロケールに対応しています。翻訳の正本はXcodeの文字列カタログです。

## Start here / はじめに

- Review the localized app names in [`APP_NAMES.md`](APP_NAMES.md).
- Read terminology and product context in [`GLOSSARY.md`](GLOSSARY.md).
- Read or search the generated locale views in [`Generated/`](Generated/).
- Open a Translation issue for a correction or a new locale.
- A focused pull request may edit `Narabi/Localizable.xcstrings` and `Narabi/InfoPlist.xcstrings` directly.

## Source of truth / 正本

- `Narabi/Localizable.xcstrings`: app interface text
- `Narabi/InfoPlist.xcstrings`: app name and permission explanations
- `Docs/Localization/Generated/`: generated review views; do not edit directly

## Translation principles / 翻訳方針

- Prefer natural local expression over literal translation.
- Preserve meaning, safety information, placeholders, and product behavior.
- Keep interface text concise enough for small screens and Dynamic Type.
- State the exact locale and regional variant.
- Do not translate localization keys, product IDs, bundle IDs, file names, Narabi, or Mexenixi.
- Explain substantial app-name changes in the issue or pull request.
- Machine-assisted proposals are welcome when clearly identified, but native or fluent review is preferred before a translation is treated as final.

## Adding a language / 言語追加

A proposal should include the locale code, language name, regional variant, text direction, suggested app name, all interface strings, permission explanations, App Store metadata, in-app purchase names and descriptions, and screenshots or device checks where possible.
