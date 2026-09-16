# Documentation Scope / 文書の役割

## English

Narabi's public documents describe the released product from different viewpoints.

- `README.md` provides the product overview, background, principles, and entry points.
- `Docs/ProductSpecification.md` is the source of truth for current user-visible behavior.
- `Docs/ARCHITECTURE.md` describes ownership and responsibility boundaries in the current source code.
- `Docs/Diagrams/` contains explanatory Mermaid views of current user flow, data flow, storage, import, export, AI handoff, operations, and code structure.
- The product website uses a simpler introductory diagram; the GitHub Mermaid documents provide the detailed views.

Diagrams are explanatory representations, not separately executable specifications. Future ideas must not be presented as implemented features. When released behavior and documentation differ, contributors should either document the difference as a known limitation or update the affected source and documentation together. Paired Japanese and English public documents and diagrams should remain synchronized.

## 日本語

Narabiの公開文書は、公開済み製品を異なる視点から説明します。

- `README_ja.md`は製品の概要、背景、考え方、各資料への入口を示します。
- `Docs/ProductSpecification_ja.md`は、現在の公開版で利用者から確認できる動作の正本です。
- `Docs/ARCHITECTURE.md`は、現在のソースコードにおける責務と担当範囲を説明します。
- `Docs/Diagrams/`は、利用者フロー、データフロー、保存、取込み、出力、AI受け渡し、操作、コード構成を説明するMermaid図を収録します。
- 製品Webサイトでは簡易な導入図を使い、GitHubのMermaid文書を詳細図として扱います。

図は説明のための表現であり、別個の実行仕様ではありません。将来案を実装済みの機能として記載しません。公開版の動作と文書に差がある場合は、既知の制約として差を明記するか、該当する実装と文書を同時に更新します。対になっている日本語・英語の公開文書と設計図は同期を保ちます。
