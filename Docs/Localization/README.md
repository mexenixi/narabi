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

### Languages not yet included are welcome

Suggestions are welcome even when a language is not currently included in Narabi. You do not need to prepare every string, build the app, edit an Xcode string catalog, or open a pull request.

Use the Translation Issue form and choose **Add a new language**. Provide the locale code, language name, regional variant if applicable, writing direction, and as much proposed wording as you can. A partial proposal, terminology review, app-name suggestion, or offer to review a future draft is also useful. Leave **Current text** blank when the locale does not yet exist, and use **Reason and usage context** to explain regional usage, tone, script, or other requirements.

The maintainer can use an accepted proposal to prepare the string-catalog entry and generated review file. Before a new locale is treated as complete, the interface strings, permission explanations, localized app name, App Store metadata, In-App Purchase names and descriptions, layout, text direction, and representative device screens should be reviewed. This staged process lets language contributors participate without needing Swift or Xcode knowledge.

### 現在未対応の言語も歓迎します

現在Narabiに含まれていない言語についても、提案を歓迎します。すべての文字列を一度に用意したり、アプリをビルドしたり、Xcodeの文字列カタログを編集したり、Pull Requestを作成したりする必要はありません。

Translation Issueで **Add a new language** を選び、ロケールコード、言語名、必要に応じた地域差、文字方向、分かる範囲の提案文を記載してください。一部の文面だけの提案、用語の確認、アプリ名の提案、今後作成される翻訳案の確認協力だけでも役立ちます。まだ存在しないロケールでは **Current text** を空欄にし、**Reason and usage context** に地域での用法、語調、文字体系、その他の要件を記載できます。

採用できる提案をもとに、管理者が文字列カタログへの追加と閲覧用ファイルの生成を行えます。新しいロケールを完成と扱う前に、画面文言、権限説明、現地語のアプリ名、App Store掲載文、App内課金の商品名と説明、レイアウト、文字方向、代表的な実機画面を確認します。この段階的な仕組みにより、SwiftやXcodeの知識がなくても言語協力へ参加できます。

## Adding a language / 言語追加

A proposal should include the locale code, language name, regional variant, text direction, suggested app name, all interface strings, permission explanations, App Store metadata, in-app purchase names and descriptions, and screenshots or device checks where possible.
