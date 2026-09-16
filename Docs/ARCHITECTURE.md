# Architecture

This document describes source ownership. User-visible behavior is specified in `ProductSpecification.md` and `ProductSpecification_ja.md`. Visual flows are under `Docs/Diagrams/`.

## Boundaries

- `App`: app entry, root navigation, and scene restoration
- `Models`: persisted and shared value models
- `Stores`: project-browser state, ordering, serialized persistence requests, and recovery
- `Services`: image, PDF, scan, document, OCR, export, and AI handoff pipelines
- `Views/Projects`: project and one-level-folder browsing
- `Views/Import`: uncommitted new-project import and shared progress UI
- `Views/Editor`: editor session state and actions
- `Views/Workspace`: UIKit-backed high-volume page workspace
- `Views/Composite`: layered composition
- `Settings`: user settings, appearance, and public links
- `Legal`: bundled legal documents

## Editor ownership

- `EditorView.swift`: screen state, sheets, dialogs, overlays, lifecycle
- `EditorViewControls.swift`: controls and Workspace wiring
- `EditorPageActions.swift`: page and area mutations
- `EditorImportActions.swift`: imports into Material
- `EditorExportActions.swift`: ordinary and composite export entry points
- `EditorAIWorkflow.swift`: AI handoff and result application
- `EditorHistoryActions.swift`: Undo, Redo, close, naming, save forwarding
- `EditorPreviewViews.swift`: full-screen page and composite previews
- `EditorSupportTypes.swift`: editor-only action values

## Workspace ownership

- `WorkspaceBoard.swift`: SwiftUI-to-UIKit bridge
- `WorkspaceBoardController.swift`: construction, layout, and state application
- `WorkspaceBoardCollection.swift`: collection updates, cells, metadata, and prefetching
- `WorkspaceBoardDragInteraction.swift`: drag state, drop targets, edge auto-scroll, and gesture arbitration
- `WorkspaceCell.swift`: reusable page presentation
- `WorkspaceThumbnailLoader.swift`: asynchronous loading, request coalescing, and bounded cache

## Document import ownership

- `OfficeImportService.swift`: single system-preview fallback for approved legacy formats
- `DocumentPageImportService.swift`: supported-format routing and OOXML access
- `DocumentTextPageRenderer.swift`: block-based page rendering used by OOXML and delimited text
- `StructuredDocumentImport.swift`: Core Text pagination and JSON, XML, YAML, HTML, and calendar importers
- `DocumentXMLParsers.swift`: XML text extraction used by OOXML
- `DOCXDocumentParser.swift`: DOCX paragraphs, tables, and declared page breaks
- `XLSXDocumentParsers.swift`: shared strings, worksheets, and cell values
- `DelimitedTextParser.swift`: CSV and TSV

DOCX, XLSX, and PPTX use independent on-device page creation. They are not Office-compatible renderers.

## Persistence

`ProjectStore` owns MainActor-observable collections. Persistence requests are debounced and executed by one serialized worker. `ProjectPersistence` writes changed projects individually, commits the index after project files, performs atomic replacement, retains backups, and supports the legacy all-projects format.

Undo and Redo are separate, bounded Editor-session concerns. Thumbnail cache is also bounded and is not persisted.

## Current Responsibility Boundaries

The current structure intentionally keeps UI coordination separate from reusable decision and processing code.

- **Views and controllers** coordinate SwiftUI/UIKit state, presentation, gestures, selection, and system UI.
- **Policies** contain deterministic decisions and state transformations, including workspace layout and drag rules, project-browser selection and movement, import selection and format routing, page-edit results, placement, and composite-layout changes.
- **Services and loaders** perform staged import, project creation, document conversion, AI handoff, export, and other effectful workflows.
- **Engines and renderers** perform document correction, page rendering, preview generation, and output rendering.
- **Models, stores, and persistence** own format-neutral state, observable collections, serialized saving, backups, and recovery.

Representative extracted components include `WorkspaceLayoutPolicy`, `WorkspaceDragPolicy`, `ProjectBrowserSelectionPolicy`, `ProjectBrowserDragPolicy`, `ImportSelectionPolicy`, `ImportFormatPolicy`, `NewProjectImportItemLoader`, `PageEditResultPolicy`, `PagePlacementPolicy`, `CompositeLayoutPolicy`, and `DocumentCorrectionEngine`.

Dependencies should normally point from UI coordination toward these reusable components, then toward models, persistence, and renderers. Policies must not depend on concrete screen presentation. This boundary allows core behavior to be covered by unit tests without duplicating UIKit or SwiftUI interactions.

## Naming

`NarabiProject` and `ProjectPage` are format-neutral models. `Narabi` remains the internal module, target, bundle, and storage namespace for compatibility. Public product names are 並び替えでポン and Sort & Done!.

## Diagrams

- [User flow](Diagrams/USER_FLOW.md)
- [Data flow](Diagrams/DATA_FLOW.md)
- [Storage and recovery](Diagrams/STORAGE_AND_RECOVERY.md)
- [Import pipeline](Diagrams/IMPORT_PIPELINE.md)
- [Export pipeline](Diagrams/EXPORT_PIPELINE.md)
- [AI handoff](Diagrams/AI_HANDOFF.md)
- [Code architecture](Diagrams/CODE_ARCHITECTURE.md)
- [Operations matrix](Diagrams/OPERATIONS_MATRIX.md)

## New project creation progress

`ImportView` owns user interaction and final project registration. `NewProjectCreationService` converts staged `ImportItem` values into `ProjectPage` values and reports item/page progress. `ImportProgressOverlay` presents both import progress and final project preparation. Project creation completes before navigation to `EditorView`.

## Export temporary-file lifetime

Page-separated JPEG and PNG exports are created in Narabi-owned `NarabiImageExport-` temporary directories. Closing the system share sheet releases the app's UI references but does not immediately delete the files, because a selected destination may still be reading them. On a later app launch, `TemporaryFileMaintenance` removes only Narabi-owned export directories and the `NarabiAIFiles` directory after they are at least 24 hours old. It never classifies arbitrary temporary PDF, JPEG, or PNG files as Narabi-owned by extension alone.
