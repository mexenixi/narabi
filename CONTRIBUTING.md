# Contributing / コントリビューション

Narabi welcomes bug reports, device-specific test results, accessibility feedback, localization suggestions, and focused pull requests.

Before submitting:

- do not include real confidential documents or personal information;
- describe the device, system version, app version, and reproducible steps;
- preserve the product behavior documented in `Docs/ProductSpecification.md` unless proposing an explicit specification change;
- clearly mark files that were changed;
- do not use Narabi or mexenixi branding for a derivative distribution.

Narabiでは、不具合報告、端末別の検証結果、アクセシビリティ上の意見、翻訳提案、範囲の明確なPull Requestを歓迎します。

投稿時は次を守ってください。

- 実在する機密文書や個人情報を含めない。
- 端末、システムバージョン、アプリバージョン、再現手順を記載する。
- 明示的な仕様変更提案でない限り、`Docs/ProductSpecification_ja.md`の製品挙動を維持する。
- 変更したファイルを明確にする。
- 派生配布にNarabiまたはmexenixiのブランドを使用しない。

## Required Checks

Before submitting a pull request, run the repository audits and the complete `NarabiTests` target. Swift changes must follow the repository format configuration. When changing paired Japanese and English public documents or Mermaid diagrams, update both versions in the same pull request.

GitHub Actions repeats repository audits on Ubuntu and unit tests on a macOS iPhone Simulator. Release verification and physical-device checks remain required for changes that affect production integration, system UI, import, export, persistence, or gestures.

## Translation / 翻訳

Translation corrections and new-language proposals are welcome. You do not need to build the app or edit source code to contribute through a Translation issue. Start with [`Docs/Localization/README.md`](Docs/Localization/README.md), review the localized app names, and use the Translation issue template. The Xcode string catalogs are the source of truth; generated locale review files are for reading and search only.

翻訳修正と新しい言語の提案を歓迎します。Translation Issueから提案する場合、アプリのビルドやソースコードの編集は必要ありません。まず[`Docs/Localization/README.md`](Docs/Localization/README.md)を読み、各言語のアプリ名を確認し、翻訳Issueテンプレートを利用してください。正本はXcode文字列カタログであり、言語別の生成ファイルは閲覧・検索用です。
