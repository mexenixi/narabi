# Code Architecture

```mermaid
flowchart TD
    UI[SwiftUI Views and UIKit Controllers]
    POL[Policies\nDeterministic decisions and state changes]
    SVC[Services and Loaders\nImport, creation, export, AI handoff]
    ENG[Engines and Renderers\nCorrection, preview, page and output rendering]
    MOD[Models and Stores\nProjects, pages, observable state]
    PER[Persistence and Recovery\nSerialized writes, backups, migration]
    SYS[iOS and iPadOS System UI\nPickers, Photos, print, share sheet]

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

Representative policies include workspace layout and drag rules, project-browser selection and movement, import selection and format routing, page-edit results, placement, and composite-layout changes. `NewProjectImportItemLoader` performs staged import loading, and `DocumentCorrectionEngine` performs correction outside the editing view. UI code remains responsible for presentation and interaction timing.
