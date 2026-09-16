#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
source_root = root / "Narabi"
swift_files = sorted(source_root.rglob("*.swift"))
issues = []
warnings = []

required_files = [
    "Narabi/Models/AISortModels.swift",
    "Narabi/Models/ExportModels.swift",
    "Narabi/Models/ImportItem.swift",
    "Narabi/Models/PagePlacementPolicy.swift",
    "Narabi/Models/PageRenderGeometry.swift",
    "Narabi/Models/PaperModels.swift",
    "Narabi/Models/ProjectFolder.swift",
    "Narabi/Models/NarabiProject.swift",
    "Narabi/Models/ProjectPage.swift",
    "Narabi/Stores/ProjectPersistence.swift",
    "Narabi/Services/EditorImportPipeline.swift",
    "Narabi/Services/OfficeImportService.swift",
    "Narabi/Services/DocumentPageImportService.swift",
    "Narabi/Services/DocumentTextPageRenderer.swift",
    "Narabi/Services/StructuredDocumentImport.swift",
    "Narabi/Services/DocumentXMLParsers.swift",
    "Narabi/Services/DOCXDocumentParser.swift",
    "Narabi/Services/XLSXDocumentParsers.swift",
    "Narabi/Services/DelimitedTextParser.swift",
    "Narabi/Views/Workspace/WorkspaceBoard.swift",
    "Narabi/Views/Workspace/WorkspaceBoardController.swift",
    "Narabi/Views/Workspace/WorkspaceBoardCollection.swift",
    "Narabi/Views/Workspace/WorkspaceBoardDragInteraction.swift",
    "Narabi/Views/Workspace/WorkspaceCell.swift",
    "Narabi/Views/Workspace/WorkspaceThumbnailLoader.swift",
    "Narabi/Views/Editor/EditorView.swift",
    "Narabi/Views/Editor/EditorViewControls.swift",
    "Narabi/Views/Editor/EditorPageActions.swift",
    "Narabi/Views/Editor/EditorImportActions.swift",
    "Narabi/Views/Editor/EditorExportActions.swift",
    "Narabi/Views/Editor/EditorAIWorkflow.swift",
    "Narabi/Views/Editor/EditorHistoryActions.swift",
    "Narabi/Views/Editor/EditorSupportTypes.swift",
    "Narabi/Views/Editor/EditorPreviewViews.swift",
    "Narabi/Views/Editor/PageEditPreviewViews.swift",
    "Narabi/Views/Editor/DeletedItemsView.swift",
    "Narabi/Views/Editor/PaperPlacementPreviewViews.swift",
    "Narabi/Views/Editor/PlacementGestureSurface.swift",
    "Narabi/Views/Import/ImportPreviewViews.swift",
    "Narabi/Views/Composite/CompositeLayoutEditor.swift",
    "Narabi/Views/Composite/CompositeLayoutEditorActions.swift",
    "Narabi/Views/Composite/CompositeLayerStrip.swift",
    "Narabi/Views/Composite/CompositeSupportViews.swift",
]
for relative in required_files:
    if not (root / relative).is_file():
        issues.append(f"missing required file: {relative}")

all_source = "\n".join(path.read_text(encoding="utf-8") for path in swift_files)

expected_declarations = {
    "NarabiProject": "Narabi/Models/NarabiProject.swift",
    "ProjectPage": "Narabi/Models/ProjectPage.swift",
    "WorkspaceBoard": "Narabi/Views/Workspace/WorkspaceBoard.swift",
    "WorkspaceBoardController": "Narabi/Views/Workspace/WorkspaceBoardController.swift",
    "WorkspaceCell": "Narabi/Views/Workspace/WorkspaceCell.swift",
    "EditorView": "Narabi/Views/Editor/EditorView.swift",
    "CompositeLayoutEditor": "Narabi/Views/Composite/CompositeLayoutEditor.swift",
    "CompositeLayerStrip": "Narabi/Views/Composite/CompositeLayerStrip.swift",
    "CompositePreviewItem": "Narabi/Views/Editor/EditorPreviewViews.swift",
    "CompositeExportPreview": "Narabi/Views/Editor/EditorPreviewViews.swift",
}
for name, expected_file in expected_declarations.items():
    matches = []
    declaration = re.compile(
        rf"(?m)^\s*(?:private\s+|fileprivate\s+|internal\s+|public\s+|open\s+)?"
        rf"(?:nonisolated\s+)?(?:final\s+)?(?:struct|class|enum|actor)\s+{re.escape(name)}\b"
    )
    for path in swift_files:
        if declaration.search(path.read_text(encoding="utf-8")):
            matches.append(str(path.relative_to(root)))
    if matches != [expected_file]:
        issues.append(f"{name} declaration locations: {matches}; expected [{expected_file}]")

preview_source = (root / "Narabi/Views/Editor/EditorPreviewViews.swift").read_text(encoding="utf-8")
for name in ["CompositePreviewItem", "CompositeExportPreview"]:
    if re.search(rf"(?m)^\s*private\s+struct\s+{name}\b", preview_source):
        issues.append(f"{name} must be internal for cross-file use")
if not re.search(r"(?m)^\s*private\s+struct\s+ZoomableEditorImagePreview\b", preview_source):
    issues.append("ZoomableEditorImagePreview should remain private")

controller_source = (
    root / "Narabi/Views/Workspace/WorkspaceBoardController.swift"
).read_text(encoding="utf-8")
if not re.search(
    r"(?m)^@MainActor\s*\nfinal class WorkspaceBoardController\b",
    controller_source,
):
    issues.append("WorkspaceBoardController must remain @MainActor")

for path in swift_files:
    source = path.read_text(encoding="utf-8")
    relative = path.relative_to(root)
    if source.count("{") != source.count("}"):
        issues.append(f"brace imbalance: {relative}")
    if re.search(r"catch\s*\{\s*\}", source, re.DOTALL):
        issues.append(f"empty catch: {relative}")
    if "try!" in source:
        issues.append(f"force try: {relative}")
    if "as!" in source:
        issues.append(f"force cast: {relative}")
    if re.search(r"(?m)^@\w+(?:\([^\n]*\))?\s*$", source.rstrip().splitlines()[-1] if source.strip() else ""):
        issues.append(f"dangling attribute at end of file: {relative}")
    line_count = len(source.splitlines())
    if line_count > 1_200:
        warnings.append(f"large file over 1200 lines: {relative} ({line_count})")


for unsupported in ["rtf", "rtfd"]:
    if re.search(rf'"{unsupported}"|\.{unsupported}\b', all_source, re.IGNORECASE):
        issues.append(f"unsupported format returned to source: {unsupported}")

obsolete_terms = ["PDFProject", "PDFPageItem", "PerformanceTrace"]
for term in obsolete_terms:
    if re.search(rf"\b{re.escape(term)}\b", all_source):
        issues.append(f"obsolete Swift term remains: {term}")

required_markers = {
    "serialized persistence": "while persistenceRequested",
    "project-scoped manifest": "projectIndex.json",
    "30-operation history": "maximumEntryCount = 30",
    "responsive editor close": "closeEditorImmediately",
    "asynchronous thumbnails": "WorkspaceThumbnailLoader",
    "background perspective correction": "Task.detached(priority: .userInitiated)",
}
for description, marker in required_markers.items():
    if marker not in all_source:
        issues.append(f"required architecture marker missing: {description}")

print("POST-SPLIT ARCHITECTURE AUDIT")
for warning in warnings:
    print("WARNING:", warning)
for issue in issues:
    print("ERROR:", issue)
print(f"WARNINGS: {len(warnings)}")
print(f"ERRORS: {len(issues)}")
sys.exit(1 if issues else 0)

# Final pre-website invariants
check("Launch-time Photos permission removed", "PhotoPermissionManager" not in read("Narabi/App/NarabiApp.swift"))
check("No empty DEBUG blocks", "#if DEBUG\n#endif" not in all_swift and "#if DEBUG\n            #endif" not in all_swift)
check("Public permission fallback name", "Narabi uses the camera" not in read("Narabi.xcodeproj/project.pbxproj"))
check("Project browser force unwrap removed", "project!.id" not in read("Narabi/Stores/ProjectStore.swift"))
