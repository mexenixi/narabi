# Quality

Narabi combines physical-device testing with reproducible repository checks.

```bash
./Scripts/audit_all.sh
```

The audit checks required legal and privacy files, all 21 localization entries, accidental signing material, personal absolute paths, internal backup artifacts, force-try usage, empty catches, long lines, and unusually large Swift files. Warnings require review and do not automatically indicate a defect. Automated checks do not guarantee that the app is bug-free.

The combined audit also verifies post-split file ownership, cross-file access levels, unique declarations, MainActor placement, bounded Undo history, serialized project persistence, asynchronous thumbnails, and the responsive editor-close path.
