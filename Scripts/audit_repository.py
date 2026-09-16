#!/usr/bin/env python3
from pathlib import Path
import json, re, sys

root = Path(__file__).resolve().parents[1]
errors = []
warnings = []
required = [
    "Narabi/PrivacyInfo.xcprivacy",
    "Narabi/Legal/Terms_ja.md", "Narabi/Legal/Terms_en.md",
    "Narabi/Legal/Privacy_ja.md", "Narabi/Legal/Privacy_en.md",
    "LICENSE", "NOTICE",
]
for item in required:
    if not (root / item).exists():
        errors.append(f"missing required file: {item}")

user_path_pattern = r"/" + r"Users/[^/\s]+/"
for path in root.rglob("*"):
    if not path.is_file() or any(part in {".git", "DerivedData", "build", ".build"} for part in path.parts):
        continue
    relative = path.relative_to(root)
    if path.suffix.lower() in {".mobileprovision", ".p12", ".cer", ".key"}:
        errors.append(f"signing material: {relative}")
    if any(token in path.name for token in ("ReconstructableMaster", "FullTextBackup", "_Audit_")):
        errors.append(f"internal artifact: {relative}")
    if path.suffix.lower() not in {".swift", ".md", ".txt", ".json", ".xcstrings", ".plist", ".pbxproj", ".py", ".sh", ".command"}:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if re.search(user_path_pattern, text):
        errors.append(f"absolute user path: {relative}")
    private_key_marker = "PRIVATE" + " KEY-----"
    if private_key_marker in text:
        errors.append(f"private key: {relative}")
    if path.suffix == ".swift":
        if "try!" in text:
            errors.append(f"force try: {relative}")
        if re.search(r"catch\s*\{\s*\}", text, re.S):
            warnings.append(f"empty catch: {relative}")
        longest = max((len(line) for line in text.splitlines()), default=0)
        if longest > 220:
            warnings.append(f"long line {longest}: {relative}")
        count = len(text.splitlines())
        if count > 500:
            warnings.append(f"large Swift file {count} lines: {relative}")

catalog = root / "Narabi/Localizable.xcstrings"
if catalog.exists():
    data = json.loads(catalog.read_text(encoding="utf-8"))
    expected = {"ar", "de", "en", "es", "fr", "he", "hi", "id", "it", "ja", "ko", "nl", "pl", "pt-BR", "ru", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant"}
    for key, value in data.get("strings", {}).items():
        missing = expected - set(value.get("localizations", {}))
        if missing:
            errors.append(f"localization {key}: missing {sorted(missing)}")

print(f"ERRORS: {len(errors)}")
for item in errors: print("ERROR", item)
print(f"WARNINGS: {len(warnings)}")
for item in warnings: print("WARNING", item)
sys.exit(1 if errors else 0)
