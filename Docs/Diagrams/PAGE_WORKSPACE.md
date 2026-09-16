# Page Workspace

```mermaid
flowchart TD
    PROJECT[Project pages]
    BOARD[WorkspaceBoardController\nUI, collections, selection and presentation]
    LAYOUT[WorkspaceLayoutPolicy\niPhone and iPad columns, cell size]
    DRAG[WorkspaceDragPolicy\ndrop destination and movement decisions]
    EDIT[Editor area\ncurrent output order]
    TRAY[Tray\nretained but excluded pages]
    DELETED[Deleted pages\nrecoverable until permanent deletion]
    OUTPUT[Export uses editor order]

    PROJECT --> BOARD
    BOARD --> LAYOUT
    BOARD --> DRAG
    BOARD --> EDIT
    BOARD --> TRAY
    EDIT <--> TRAY
    EDIT --> DELETED
    TRAY --> DELETED
    DELETED --> EDIT
    DELETED --> TRAY
    EDIT --> OUTPUT
```

The extraction of layout and drag policies does not change the user-facing workspace behavior. The controller still coordinates scrolling, gestures, collection views, selection, and the tray; reusable calculations and decisions are covered independently by unit tests.
