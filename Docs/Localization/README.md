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

## AI-assisted translation review / AIを利用した翻訳確認

Some initial wording and translation review used Microsoft Copilot as an assistive tool. AI assistance is not treated as proof of linguistic quality. Native and fluent review of naturalness, regional usage, terminology, tone, and screen length is especially welcome.

初期文面の作成や翻訳確認の一部では、支援ツールとしてMicrosoft Copilotを使用しました。AIによる支援を言語品質の保証とは扱いません。自然さ、地域差、用語、語調、画面上の長さについて、母語話者や日常的にその言語を使う方の確認を特に歓迎します。

## Adding a language / 言語追加

A proposal should include the locale code, language name, regional variant, text direction, suggested app name, all interface strings, permission explanations, App Store metadata, in-app purchase names and descriptions, and screenshots or device checks where possible.
