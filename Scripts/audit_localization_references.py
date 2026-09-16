#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
root=Path(__file__).resolve().parents[1]
cat=json.loads((root/'Narabi/Localizable.xcstrings').read_text(encoding='utf-8'))['strings']
patterns=[re.compile(r'L10n\.(?:text|format)\(\s*"([^"]+)"'),re.compile(r'String\(localized:\s*"([^"]+)"'),re.compile(r'NSLocalizedString\(\s*"([^"]+)"')]
refs=[]
for p in (root/'Narabi').rglob('*.swift'):
    s=p.read_text(encoding='utf-8')
    for pat in patterns:
        for m in pat.finditer(s): refs.append((m.group(1),p.relative_to(root),s.count('\n',0,m.start())+1))
missing=[x for x in refs if x[0] not in cat]
if missing:
    for key,p,line in missing: print(f'ERROR localization reference missing: {key} at {p}:{line}')
    sys.exit(1)
print(f'LOCALIZATION REFERENCE AUDIT: {len(refs)} literal references, 0 missing keys')
