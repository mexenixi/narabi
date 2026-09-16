# コード構成

```mermaid
flowchart TD
    UI[SwiftUI ViewとUIKit Controller]
    POL[Policy\n決定的な判定と状態変換]
    SVC[ServiceとLoader\n取込み・作成・出力・AI受け渡し]
    ENG[EngineとRenderer\n補正・プレビュー・ページ・出力描画]
    MOD[ModelとStore\nプロジェクト・ページ・監視可能な状態]
    PER[永続化と復旧\n直列保存・バックアップ・移行]
    SYS[iOS・iPadOSのシステムUI\nピッカー・写真・印刷・共有]

    UI --> POL
    UI --> SVC
    UI --> ENG
    UI --> SYS
    POL --> MOD
    SVC --> MOD
    SVC --> ENG
    ENG --> MOD
    MOD --> PER
```

代表的なPolicyは、ワークスペースのレイアウトとドラッグ、プロジェクト一覧の選択と移動、取込み選択と形式経路、ページ編集結果、配置、重ね合わせ変更を担当します。`NewProjectImportItemLoader`は段階的な取込み読込みを、`DocumentCorrectionEngine`は編集画面の外で書類補正を担当します。画面コードは表示と操作タイミングの調停を担います。
