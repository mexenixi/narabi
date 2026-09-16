# Design diagrams

Narabi's diagrams are maintained in separate English and Japanese Mermaid documents. The website uses a deliberately simpler static SVG so that the product page remains stable and does not require Mermaid JavaScript.

## Start here

- [Concept overview](CONCEPT_OVERVIEW.md) / [コンセプト概要](CONCEPT_OVERVIEW_ja.md)
- [User flow](USER_FLOW.md) / [利用者フロー](USER_FLOW_ja.md)
- [Page workspace](PAGE_WORKSPACE.md) / [ページワークスペース](PAGE_WORKSPACE_ja.md)

## Processing and trust boundaries

- [Import pipeline](IMPORT_PIPELINE.md) / [取込みパイプライン](IMPORT_PIPELINE_ja.md)
- [Export pipeline](EXPORT_PIPELINE.md) / [出力パイプライン](EXPORT_PIPELINE_ja.md)
- [AI handoff](AI_HANDOFF.md) / [AI受け渡し](AI_HANDOFF_ja.md)
- [Storage and recovery](STORAGE_AND_RECOVERY.md) / [保存と復旧](STORAGE_AND_RECOVERY_ja.md)

## Implementation reference

- [Data flow](DATA_FLOW.md) / [データフロー](DATA_FLOW_ja.md)
- [Code architecture](CODE_ARCHITECTURE.md) / [コード構成](CODE_ARCHITECTURE_ja.md)
- [Operations matrix](OPERATIONS_MATRIX.md) / [操作対応表](OPERATIONS_MATRIX_ja.md)

## Reading guide

Solid arrows show the normal product flow. Dashed arrows show optional handoff or feedback paths. Double-bordered nodes represent iOS or external destinations outside Narabi. The website diagram is introductory; these Mermaid documents are the source of detailed design information.

## Maintenance

Japanese and English diagram pairs must be updated together. User-facing flow diagrams change only when product behavior changes; code-architecture diagrams also change when internal responsibility boundaries move without a feature change.
