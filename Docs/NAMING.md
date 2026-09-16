# Naming conventions

## Product and repository

- **並び替えでポン** is the Japanese product name.
- **Sort & Done!** is the English product name.
- **Narabi** is the stable internal module, bundle, and local-storage namespace. It is intentionally retained for compatibility.

## Core model terms

- `NarabiProject` represents one saved workspace.
- `ProjectPage` represents one editable page, regardless of whether the source was an image, scan, PDF, independently pageized document, or system-generated fallback preview.
- `pages`, `tray`, and `deleted` are persisted areas. User-facing text may localize these terms differently.

PDF-specific names remain only where the implementation genuinely creates, reads, or writes PDF data. Legacy migration names remain where required to read previously saved user data.

## Model file ownership

- `NarabiProject.swift` owns project-level persisted state.
- `ProjectPage.swift` owns page-level persisted state.
- `ProjectFolder.swift` owns browser folder metadata.
- `ImportItem.swift` owns transient import selection data.
- `ExportModels.swift` owns export configuration values.
- `AISortModels.swift` owns the AI handoff request schema.
