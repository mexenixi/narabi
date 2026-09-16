# Sort & Done! Product Specification

- Document version: 1.0
- Target app version: 1.0
- Status: Version 1 product specification
- Developer and operator: Mizuki Kubo, operating under the trade name “Mexenixi”
- Implementation baseline: September 4, 2026

## 1. Role of this document

This document is the product-level source of truth for behavior observable in the current Swift implementation. The README provides an overview, ARCHITECTURE describes internal ownership, and this specification describes user actions and outcomes. Future ideas are not presented as implemented features.

## 2. Product overview

Sort & Done! is a local-first iPhone and iPad app for importing photos, images, scans, PDFs, and supported documents as pages, then arranging, editing, organizing, and exporting them.

- No account is required.
- No advertising SDK, behavioral tracking, or proprietary analytics SDK is used.
- Projects are not automatically uploaded to a server operated by the developer.
- All functional features are available without charge.
- Optional support purchases do not change editing features, storage capacity, support priority, or any other practical capability; they provide a locally stored randomized thank-you message.
- No proprietary cloud synchronization is provided.
- The App is not a medical device, legal decision service, accounting or tax service, or other professional service.

## 3. Screens and primary navigation

### 3.1 Home

Home provides New Project, Continue, Support Development, Settings, and contact-related entry points.

- New Project opens the uncommitted import screen.
- Continue opens the root project browser.
- The App records Home, New Project, Project Browser, and an existing project’s Editor as restorable scene states.
- If a stored project no longer exists, restoration falls back to the project browser.

### 3.2 Project browser

The root can mix projects and one level of folders. A folder contains projects only and cannot contain another folder.

- Manual order is persisted.
- Search covers project names and containing-folder names.
- Search ignores case, diacritics, and width differences.
- Long-press actions provide selection, rename, duplicate, move, and delete.
- Duplicating a folder deep-copies its projects with independent IDs.
- Deleting a folder confirms that its projects will also be deleted.
- Closing a project opened from a folder returns to that folder.
- Opening Continue from Home starts at the root.

### 3.3 Editor

The Editor manages three persistent areas.

- **Editor area:** pages included in ordinary output, kept in output order.
- **Material tray:** candidates, temporary material, and replacement pages excluded from ordinary output.
- **Deleted area:** pages waiting for restoration or permanent deletion.

## 4. Creating a project

### 4.1 Import entry points

The New Project screen presents Photos, Files, and Scan in that order. Selected items are staged before project creation and can be previewed, selected, and reordered.

### 4.2 Photos

- Photos load sequentially in selection order.
- Completed and total counts are shown.
- Confirmation, Back, Reorder, and further import actions are disabled while loading.
- Unreadable photos are not added, while later readable items may continue. The release candidate must be checked to ensure a partial import is sufficiently clear to the user.

### 4.3 Files

`SUPPORTED_IMPORT_FORMATS.md` is the authoritative format list.

- PDFs expand into individual pages when the project is confirmed.
- A common image normally becomes one page.
- DOCX, XLSX, and PPTX are reorganized on the device into the App’s own pages, prioritizing readable content and order rather than file-format compatibility.
- Supported text and structured-data formats, including TXT, Markdown, LOG, CSV, TSV, JSON, XML, YAML, HTML, and ICS, are pageized according to their structure.
- Certain older Office or iWork files may use one system-generated fallback preview when iOS can create one.
- Source files are not overwritten, moved, or deleted.
- Office Open XML containers use safety limits for input size, entry count, expansion, compression ratio, and generated pages. Files exceeding a safety limit are not added.

### 4.4 Scanning

The document camera adds captured images in scanner result order. When camera access is unavailable, the App presents the relevant permission flow.

### 4.5 Confirmation

A project is created only if at least one usable page results. Unconfirmed New Project items are not guaranteed to survive operating-system termination.

## 5. Adding to an existing project

Photos, files, and scans can be added to the Material tray. Multi-file imports, multi-page PDFs, and large documents use a shared progress presentation and support cancellation.

- File, page or processing-unit counts, and generated-page counts may be shown.
- Cancellation is observed at safe processing boundaries.
- Pages from the current operation are not committed to the tray if cancellation occurs before commit.
- Source files and existing project pages are left unchanged.
- Photos already saved during an output operation cannot be revoked by a later cancellation.

## 6. Selection, arrangement, and movement

### 6.1 Selection

- Editor and Material tray have separate selection modes.
- Selected pages receive numbers beginning at one.
- Removing a selection compacts the remaining numbers in selection order.
- Select All follows display order. Clear All changes selection only.
- Selected export and AI sorting use selection-number order.

### 6.2 Drag interaction

- Pages can be long-pressed and dragged within either area and between areas.
- Multi-page movement preserves selection order.
- A second finger can scroll while a drag remains active.
- Edge auto-scroll uses a safe margin to avoid accidental activation.
- Thumbnails are loaded asynchronously and prefetched. Large thumbnails are not synchronously generated when a cell appears.

### 6.3 Dropping Material onto an Editor page

The App offers three distinct operations.

- **Add:** keep the existing Editor page and add the Material page.
- **Swap:** exchange the areas of the two pages.
- **Replace:** use the Material page and move the replaced Editor page to Deleted.

### 6.4 Duplication and hiding

Editor and Material pages can be duplicated. A duplicate retains content and editing state, receives a new page ID, and is inserted after its source. A hidden page remains in Editor but is excluded from ordinary output.

## 7. Page editing

A page can retain and edit:

- rotation;
- crop;
- color, grayscale, or black and white;
- paper preset and orientation;
- custom paper size;
- millimeters, centimeters, or inches;
- scale;
- X and Y position;
- placement rotation;
- hidden-from-output state;
- document correction.

The App does not directly overwrite the source image. Source data, edit-base data, current rendered data, and editing values are retained in the project.

### 7.1 Document correction

- Orientation is normalized.
- Rectangle candidates are detected.
- Candidate switching and manual corner adjustment are available.
- Perspective correction runs away from the main UI work.
- Duplicate Apply actions are prevented while processing.
- A failed correction does not replace the source result.

### 7.2 Paper placement

A3, A4, A5, B4, B5, Letter, Legal, postcard, 4 × 6 photo, and custom paper are supported. Trusted physical dimensions may be used for actual-size placement. Physical left and right, rotation, and coordinates do not reverse in RTL interfaces.

## 8. Deleted pages and permanent deletion

- Ordinary deletion moves pages to Deleted.
- Restoration returns pages to Material.
- Delete Permanently removes pages from the current saved state and Deleted area.
- Restoration may remain possible while the current Editor session still holds an undo state containing the prior project state.
- Restoration is unavailable after the relevant history is discarded, including after leaving the Editor, exceeding the history limit, restarting the App, or deleting the project.
- No additional confirmation popup interrupts this page-level operation.

## 9. Undo and Redo

- Up to 30 operations are retained.
- Reorder, area movement, duplication, deletion, restoration, and committed page edits are included.
- A grouped multi-page change is one operation.
- A new change after Undo clears Redo.
- Selection, scrolling, Material visibility, and share-sheet presentation are not history operations.
- History assists the current Editor session and is not guaranteed across relaunch.
- Undo does not unnecessarily change the Material tray’s collapsed state.

## 10. Ordinary export

### 10.1 Targets and order

With no selection, Editor order is used. With a selection, selection-number order is used. Hidden pages, Material pages, and Deleted pages are excluded. Export does not begin with zero targets.

### 10.2 Formats

- PDF
- JPEG
- PNG
- transparent PNG
- Photos library

### 10.3 Settings

- output name;
- output format;
- paper and orientation;
- image long edge: Original, 1200, 1600, 2048, 3072, or 4096 px;
- JPEG quality;
- Per Page, All Color, All Grayscale, or All Black and White.

Only settings relevant to the selected format are shown. Image-long-edge and JPEG-quality controls apply to image output. PDF output reflects paper, physical size, and placement.

### 10.4 Progress, cancellation, and failure

Large exports provide progress and cancellation. JPEG, PNG, and transparent PNG are built in an operation-specific temporary directory. A render, encoding, write, or verification failure prevents partial results from being shared. Successful-output milestones are recorded only when the selected destination reports completion without an error.

## 11. Composite editing

Composite editing places multiple pages as independent layers on one canvas.

- The ordinary output target-and-order rules apply.
- The first target page supplies the initial canvas basis.
- Each layer can reflect scale, position, rotation, color, crop, and visibility.
- Content outside the canvas is clipped.
- Editing uses lightweight layers. High-quality composition occurs for final preview or export.
- Save applies placement to pages. Cancel discards unsaved composite changes.
- Dismissing a share sheet keeps the composite editing state.
- PDF, JPEG, PNG, transparent PNG, and Photos are supported.

## 12. AI-assisted sorting

The App does not connect directly to an external AI provider. The user creates a handoff file and chooses a destination in the system share sheet.

### 12.1 Handoff formats

- PDF, high accuracy;
- PDF, lightweight;
- TXT, OCR of current images;
- TXT, document-correction attempt before OCR.

A package may contain selected-page images or OCR text, sorting instructions, a session ID, PAGE_ID values, current positions, and a fixed response format.

### 12.2 Safety notice

Before sharing, the App explains that personal, confidential, sensitive, or third-party information should be reviewed. The App does not record the selected destination. The external service’s terms and privacy policy apply after sharing.

### 12.3 Applying a result

The App validates syntax, session, the PAGE_ID set, missing IDs, duplicates, extra IDs, and target count. A result is applied only after user confirmation. When sorting selected pages only, unaffected pages keep their relative order.

## 13. Persistence, recovery, and restoration

### 13.1 Persistence

- `NarabiAppData` under Application Support is the internal storage root.
- Folder information and a project index are stored.
- Each project is stored under `Projects/<UUID>/project.json`.
- Only projects whose revision changed are encoded.
- Save requests are debounced and serialized through one persistence worker.
- A generation value prevents an older save from superseding newer state.
- The previous valid file is retained as backup.
- A failed primary decode falls back to backup and repairs the primary.
- The legacy all-projects format remains readable for migration.

### 13.2 Scene restoration

Home, New Project, Project Browser with its open folder, and the Editor for an existing project are restorable. Photo and file pickers, the scanner, share sheets, confirmation dialogs, active export, and active AI-package creation are not restored.

### 13.3 Closing the Editor

The screen transition is accepted before a heavy Store update. The final project state is captured, the browser is shown, and the Store is updated afterward. A project opened from a folder returns to that folder.

## 14. Settings

The App stores:

- app language;
- System, Light, or Dark appearance;
- output format, image long edge, JPEG quality, and output color;
- AI reading mode, quality, and correction policy;
- AI sorting instructions.

The previous applicable settings are remembered. Settings irrelevant to the current format are not shown.

## 15. Languages and accessibility

The App provides 21 languages: Japanese, English, Simplified Chinese, Traditional Chinese, Korean, Spanish, French, German, Brazilian Portuguese, Italian, Dutch, Polish, Turkish, Indonesian, Thai, Vietnamese, Hindi, Arabic, Hebrew, Russian, and Ukrainian.

- General UI follows RTL layout where appropriate.
- Physical page direction and spatial interaction meaning do not reverse.
- VoiceOver labels, selection numbers, textual progress, and non-color-only state cues are used.
- Critical actions should remain reachable with Dynamic Type.
- Longer translations are considered in layout.

## 16. Support purchases

- All functionality is free.
- Products are A Little Support, Generous Support, and Big Support.
- They are repeatable consumable StoreKit products.
- They do not change editing features, storage capacity, priority response, or any other practical capability.
- Only verified transactions count as successful.
- Failure, cancellation, or an unverified result does not restrict functionality.

## 17. Privacy boundary

- Projects, images, documents, and OCR are generally processed on the device.
- No developer server, advertising, analytics, or behavioral tracking is used.
- Information leaves through an explicit user action such as sharing, email, Photos saving, or file saving.
- Apple handles payment credentials and payment processing.
- The privacy policy published on the website is canonical. The Japanese and English copies bundled in Narabi/Legal/ are synchronized offline-reading copies.

## 18. Known limitations

- Document page creation does not reproduce original layout or pagination exactly.
- A legacy-format preview depends on iOS support.
- OCR, rectangle detection, and correction may fail with unsuitable source material.
- External AI quality, service limits, and responses are not guaranteed.
- No proprietary cloud synchronization is provided.
- Undo and Redo do not persist across relaunch.
- Folders have one level only.
- Unconfirmed New Project material is not guaranteed after OS termination.
- Storage capacity, permissions, or destination availability can prevent an operation.

## 19. Implementation traceability

- Entry and restoration: `App/NarabiApp.swift`, `App/AppRootView.swift`
- Home: `Views/Home/HomeView.swift`
- New import: `Views/Import/ImportView.swift`, `ImportProgressOverlay.swift`
- Project browser: `Views/Projects/ProjectListView.swift`, `ProjectBrowserBoard.swift`
- Editor: `Views/Editor/EditorView.swift`, `EditorViewControls.swift`
- Page actions: `EditorPageActions.swift`
- Import actions: `EditorImportActions.swift`, `Services/EditorImportPipeline.swift`
- Documents: `DocumentPageImportService.swift`, `StructuredDocumentImport.swift`, `DOCXDocumentParser.swift`, `XLSXDocumentParsers.swift`
- Workspace: `Views/Workspace/WorkspaceBoard*.swift`, `WorkspaceThumbnailLoader.swift`
- Page editing: `PageEditingViews.swift`, `PaperPlacementSettings.swift`, `DocumentCorrectionView.swift`
- Deleted: `DeletedItemsView.swift`
- Export: `EditorExportActions.swift`, `ExportService.swift`, `PDFSupport.swift`, `PageRenderer.swift`
- Composite: `Views/Composite/CompositeLayoutEditor*.swift`
- AI: `EditorAIWorkflow.swift`, `AISortWaitingView.swift`, `AISortPackageService.swift`, `AIOCRService.swift`
- History and close: `EditorHistoryActions.swift`, `EditorHistoryPolicy.swift`
- Persistence: `Stores/ProjectStore.swift`, `ProjectPersistence.swift`
- Settings: `Settings/*.swift`
- Legal presentation: `Views/Legal/LegalViews.swift`, `Narabi/Legal/*.md`
- Support purchases: `Views/Support/SupportDeveloperView.swift`

## 20. Release verification

The final code must pass warning-free Debug and Release builds, repository audits, physical-device testing, and an Archive Privacy Report review. Intermediate test results are not accumulated in the public `TESTING.md`. Only tests actually run against the final release candidate are recorded.

### New project preparation progress

After the user chooses **Edit these items**, Narabi displays a blocking progress overlay while staged images and PDF pages are converted into project pages. The overlay shows the current item, completed page count, total page count, and final project-saving phase.

### Image export and system sharing

Page-separated JPEG and PNG export creates one image file per output page. PDF export creates one PDF containing the output pages. Narabi keeps its generated image files available after the system share sheet closes so that the selected destination can finish reading them, then removes expired Narabi-owned temporary directories on a later launch.

### Partial import results and save errors

When a batch contains unreadable items, successfully created pages remain available and the App reports input, success, and failure counts. If all items fail, no empty project is created. Project-persistence failures, including out-of-space errors, are surfaced at the app root.

## Optional support purchases: current behavior

Narabi keeps all editing and storage features free. The three optional products are consumable support purchases. A verified purchase displays one message selected at random from the three messages assigned to that product and the support page's selected language. The displayed message and receipt date are stored only on the device and can later be viewed from the support page. The history entrance is hidden until at least one message exists. The history can show all messages or filter by a language already present in the history. Purchase price, transaction identifier, progress, completion status, and supporter rank are not stored or displayed.

A purchase does not change editing features, storage capacity, usage restrictions, support priority, or any other practical capability. After purchase, one of three thank-you messages for the selected Support-page language and product is shown at random, and the message text and received date are stored locally on the device. Each of the three messages has an equal chance of being selected and has no different functional or monetary value.

<!-- NARABI-PRIVACY-CANONICAL:BEGIN -->
The privacy policy published on the website is canonical. `Narabi/Legal/Privacy_ja.md` and `Narabi/Legal/Privacy_en.md` are synchronized offline-reading copies and must not be edited as independent canonical documents.
<!-- NARABI-PRIVACY-CANONICAL:END -->
