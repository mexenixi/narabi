# Concept overview

Narabi converts mixed local material into format-neutral pages, organizes those pages in a persistent workspace, and lets the user take the arranged sequence out in the form they need.

```mermaid
flowchart LR
    Sources["Photos, images, scans<br/>PDFs, documents, table data"]
    Normalize["Format-neutral<br/>ProjectPage"]
    Workspace["Persistent page workspace"]
    Output["PDF, JPEG, PNG<br/>Photos and system sharing"]
    AI["Optional, user-controlled<br/>AI handoff"]

    Sources -->|Create pages on device| Normalize
    Normalize --> Workspace
    Workspace -->|Use the arranged sequence| Output
    Workspace -.->|Select pages and criteria| AI
    AI -.->|Validated order proposal| Workspace
```

AI remains outside the app's trust boundary. Narabi does not connect directly to an external AI service. The user selects the destination and reviews the returned result before applying it.
