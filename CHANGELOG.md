# Changelog

## 1.0.0 - 2026-09-16

- Released version 1.0 of the app and published the initial source and documentation baseline.
- Improved memory safety, persistence serialization, thumbnail loading, scrolling, editor closing, and document-correction responsiveness.
- Added progress and cancellation for large imports.
- Added Narabi-specific page import for supported documents and structured data.
- Refactored models, UI responsibilities, persistence, and document-import sources for public review.
- Added partial-import summaries while preserving successfully created pages.
- Added root-level project-save failure messaging, including storage-full guidance.
- Renamed the internal source-kind case to `systemPreview` while preserving the persisted raw value `officePreview`.
- Added an import-format verification matrix.
- Extended partial-import summaries to existing-project Materials Area imports and registered result and save messages in all supported localization entries.
- Focused the version 1 import scope on commonly useful page, document, text, table, structured-data, and calendar formats.
- Reworked public-facing wording to describe supported capabilities without an unnecessary exclusion list or development-stage language.
