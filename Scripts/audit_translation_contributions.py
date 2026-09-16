#!/usr/bin/env python3
from pathlib import Path
import json
import sys

root = Path(__file__).resolve().parents[1]
expected = {"ar", "de", "en", "es", "fr", "he", "hi", "id", "it", "ja", "ko", "nl", "pl", "pt-BR", "ru", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant"}
errors = []
for relative in ("Narabi/Localizable.xcstrings", "Narabi/InfoPlist.xcstrings"):
    strings = json.loads((root / relative).read_text(encoding="utf-8"))["strings"]
    for key, entry in strings.items():
        locales = set(entry.get("localizations", {}))
        if locales and locales != expected:
            errors.append(f"{relative} {key}: locales differ from supported set")
        for locale, unit in entry.get("localizations", {}).items():
            value = unit.get("stringUnit", {}).get("value", "")
            if not value.strip():
                errors.append(f"{relative} {key} {locale}: empty translation")
if not (root / "Docs/Localization/README.md").is_file():
    errors.append("missing Docs/Localization/README.md")
if not (root / ".github/ISSUE_TEMPLATE/translation.yml").is_file():
    errors.append("missing translation issue template")
if errors:
    print("TRANSLATION CONTRIBUTION AUDIT: FAILED")
    for error in errors:
        print("ERROR", error)
    sys.exit(1)
print("TRANSLATION CONTRIBUTION AUDIT: OK")
