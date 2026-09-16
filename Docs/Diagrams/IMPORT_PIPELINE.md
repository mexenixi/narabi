# Import Pipeline

```mermaid
flowchart TD
    START[User starts an import]
    ENTRY{Destination}
    NEW[Create a new project]
    EXIST[Add to an existing project]
    SELECT[ImportSelectionPolicy\nselection operations]
    FORMAT[ImportFormatPolicy\nroute by source and type]
    LOAD[NewProjectImportItemLoader\nstaged item loading]
    DOC[DocumentPageImportService]
    OFFICE[OfficeImportService]
    CREATE[NewProjectCreationService]
    PAGES[ProjectPage values]
    SAVE[ProjectStore and persistence]
    EDITOR[Editor]

    START --> ENTRY
    ENTRY -->|new project| NEW
    ENTRY -->|existing project| EXIST
    NEW --> SELECT --> FORMAT
    FORMAT -->|photos, images, PDF and supported items| LOAD
    FORMAT -->|document pages| DOC
    FORMAT -->|Office documents| OFFICE
    LOAD --> CREATE
    DOC --> CREATE
    OFFICE --> CREATE
    CREATE --> PAGES --> SAVE --> EDITOR
    EXIST --> FORMAT
    FORMAT -->|existing-project route| PAGES
```

New-project import and existing-project addition intentionally have different routing and fallback order. A document-import safety error is not silently redirected to an unrelated fallback. The UI presents progress and performs final registration, while policies, loaders, and services perform reusable decisions and conversion work.
