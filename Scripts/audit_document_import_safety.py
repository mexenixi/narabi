#!/usr/bin/env python3
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
errors = []
def has(path, token):
    return token in (ROOT / path).read_text(encoding="utf-8")
for token in ["maximumInputFileBytes","maximumArchiveEntries","maximumEntryBytes","maximumExpandedBytes","maximumCompressionRatio","maximumGeneratedPages","try budget.consume(chunk.count)"]:
    if not has("Narabi/Services/DocumentPageImportService.swift", token): errors.append("missing safety invariant: " + token)
if not (has("Narabi/Views/Editor/EditorImportActions.swift","catch is DocumentImportSafetyError") and has("Narabi/Views/Import/ImportView.swift","catch is DocumentImportSafetyError")): errors.append("safety-limit fallback handling missing")
for path in ["Narabi/Services/DOCXDocumentParser.swift","Narabi/Services/DocumentXMLParsers.swift","Narabi/Services/StructuredDocumentImport.swift","Narabi/Services/XLSXDocumentParsers.swift"]:
    text=(ROOT/path).read_text(encoding="utf-8")
    if "XMLParser(data: data)" in text and "shouldResolveExternalEntities = false" not in text: errors.append(path+": external entities not disabled")
if has("Narabi/Services/PDFSupport.swift","drawOriginalPage") or has("Narabi/Services/PDFSupport.swift","drawA4Page"): errors.append("unused PDF helper remains")
if has("Narabi/Stores/ProjectStore.swift","movingProjectIDs") or has("Narabi/Stores/ProjectStore.swift","movingFolderIDs"): errors.append("unused moving ID state remains")
print("DOCUMENT IMPORT SAFETY AUDIT")
print("ERRORS:",len(errors))
for error in errors: print("ERROR",error)
sys.exit(1 if errors else 0)
