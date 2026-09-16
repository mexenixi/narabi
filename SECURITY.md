# Security Policy / セキュリティ方針

## Reporting a Security Issue

Please do not publish sensitive document samples, personal information, credentials, or exploit details in a public issue.

Contact: `mexenixi@gmail.com`

Narabi is independently maintained. Reports may not receive an immediate response, and a response cannot be guaranteed.

## セキュリティ上の問題を報告する場合

公開Issueへ、機密文書、個人情報、認証情報、秘密鍵、または悪用可能な詳細を載せないでください。

連絡先：`mexenixi@gmail.com`

Narabiは個人で保守しています。直ちに確認・返信できない場合があり、返信を保証するものではありません。

## Untrusted document limits
DOCX, XLSX, and PPTX are treated as untrusted ZIP containers. Import limits input size, entry count, per-entry and cumulative expansion, compression ratio, and generated pages. XML external-entity resolution is explicitly disabled. Safety-limit failures are not sent to the system-preview fallback.
