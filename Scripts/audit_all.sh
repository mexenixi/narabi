#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 "$ROOT/Scripts/audit_repository.py"
python3 "$ROOT/Scripts/audit_architecture.py"

if [ -x "$ROOT/Scripts/audit_swift_format.sh" ]; then
    "$ROOT/Scripts/audit_swift_format.sh"
fi
python3 "$ROOT/Scripts/audit_document_import_safety.py"

python3 Scripts/audit_localization_references.py
python3 "$ROOT/Scripts/audit_translation_contributions.py"
