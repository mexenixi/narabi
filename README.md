# Narabi

[English](README.md) | [日本語](README_ja.md)

Narabi is a local-first iPhone and iPad app for arranging photographs, images, scanned documents, and PDF pages as one visual sequence, then exporting the result in the format the user needs.

## App Store

Narabi / Sort & Done! version 1.0 is available on the [App Store](https://apps.apple.com/app/id6809654149).

## Why Narabi Was Created

Narabi began with a need to arrange photographs and PDFs received from university classes and friends in one chosen order.

At first, the developer handled this with the Shortcuts app on iPhone. Later, a small business run by a family member faced a similar problem when organizing documents received as a mixture of photographs and PDFs. Seeing that the same need existed beyond personal use led to the decision to build Narabi as a dedicated, easier-to-use app.

Narabi does not merge imported material into one finished file at the time of import. Each item remains an arrangeable page inside the app and is combined into the chosen format only when exported. Photographs, images, scanned documents, and PDF pages can therefore be organized together without being separated by their original file type.

## Pages Instead of File Boundaries

```text
Photographs / images / scans / PDF pages
                    ↓
             pages in Narabi
                    ↓
        arrange, select, adjust, review
                    ↓
     PDF / JPEG / PNG / Photos export
```

Regardless of their original file type, imported materials are handled as pages in one common workspace.

The editor at the top shows the pages currently included in the export and their order. A page that is not needed for the current export does not have to be deleted. It can remain in the material tray below and later be returned to the editor or used as a replacement. Deleted pages can be restored until they are permanently removed.

Pages can be exported as a PDF or images in the order shown in the editor. When saving to Photos, the selected order can also be preserved.

## Focused on the Simplest Operation

Narabi keeps the interface uncluttered by bringing related features together into a small number of direct operations rather than adding a separate button for every capability.

Pages can be selected with a long press, reordered by dragging, and adjusted by interacting directly with the content. The aim is to make a broad set of operations feel discoverable and intuitive while keeping the visible interface simple.

Familiar icons are used where they can reduce reliance on language. Accessibility descriptions and visible text are still provided where needed so that a simpler visual interface does not remove essential information.

## No Prescribed Use

Narabi does not define one correct purpose or workflow for a project.

The user decides what to import, how to arrange it, which tools to explore, and how to export the result. The app is intended to let people discover the functions they need and develop their own way of using them.

A saved project is not automatically deleted after a period of inactivity. It remains on the device unless the user deletes it or removes the app, allowing unfinished work to be resumed later.

Ordinary actions such as rearranging or moving pages are saved automatically. Editing screens for operations such as cropping or compositing use Save or Cancel to confirm the result.

## All Features Free, Supported Voluntarily

Every feature in Narabi is available free of charge.

The product policy is:

- no advertising;
- no watermarks;
- no page-count limits;
- no subscriptions;
- no paid feature locks; and
- optional support purchases only.

Because Narabi is a small practical tool, it is provided with every feature available from the start rather than dividing the app into free and paid capabilities.

Optional support purchases help sustain the app's continued availability, maintenance, and updates. They do not unlock features or content, and they do not provide priority support.

## How New Features Are Added

New features should preserve Narabi's uncluttered appearance and direct, intuitive operation. Related capabilities are brought into interactions such as long press, drag, pinch, and direct manipulation instead of continually adding more visible controls.

The amount of functionality that can be added without losing the current clarity is treated as a practical limit for Narabi. A substantially different feature that cannot fit naturally within that limit may be developed as a separate Mexenixi app and connected when useful.

## Product Principles

Narabi is organized around four principles:

1. **Treat mixed inputs as pages rather than as separate file-type workflows.** Photos, scans, PDF pages, and supported documents can be handled in one workspace.
2. **Do not force users to delete material that is not part of the current export.** Candidate and replacement pages can remain in the Materials Area and return later.
3. **Do not prescribe one correct use.** Users decide what a project means, how long it remains, which tools to use, and what to export.
4. **Keep control of data and external services with the user.** Processing is local-first, no Narabi account is required, and external AI handoff occurs only through an explicit user-selected share action.

## Why Local Processing Matters

Narabi processes documents on the user's device whenever possible. This is not only a security decision. It also keeps the location of files understandable and allows material to be organized, exported, and shared on the same device where it was first received.

Documents do not always arrive on a computer first. They may reach an iPhone or iPad through email, messaging, AirDrop, photo sharing, or cloud storage. Narabi is designed to let the user review those materials as pages, arrange them, combine them into the required format, and pass them on through the sharing features provided by iOS.

No Narabi account is required. Narabi does not operate its own document-storage server or cloud synchronization service.

## The User Chooses the External AI Service

Narabi does not embed or require one specific AI provider.

The app creates an AI handoff file on the device, and the user chooses an external AI service through the iOS share sheet. Narabi does not send the file automatically. The user decides what to share and where to send it.

An order returned by an external AI service is not applied automatically. Narabi validates the session, page identifiers, duplicates, missing entries, and format, and changes the order only after the user reviews and confirms the result.

Once a file is shared, the selected external service's own terms and privacy policy apply. Files containing personal, confidential, sensitive, or third-party information should be reviewed before sharing.

## The Developer and AI-Assisted Development

Narabi began as an independent project by a student in Japan studying in a healthcare-related field rather than specializing in software development.

Microsoft Copilot was used as an assistive tool during development, including code drafting, technical investigation, documentation, translation review, and verification planning.

Product requirements, design decisions, testing, verification, release decisions, and final responsibility remain with the developer. AI-generated or AI-assisted output was reviewed and adjusted before being incorporated into the project. See [Acknowledgements](ACKNOWLEDGEMENTS.md).

## Development and Testing Environment

Primary physical devices currently used for development and verification include:

- iPhone 16 Pro;
- 11-inch iPad Air with M3;
- Mac with Apple M4 and 16 GB unified memory;
- Windows 11 PC with Intel Core i7-14700F, 32 GB DDR5 memory, GeForce RTX 5060 Ti 16 GB, and a 1 TB NVMe SSD.

The iPhone and iPad are used for user-facing workflow testing. The Mac is the main iOS and iPadOS development environment. The Windows PC supports document and image preparation and cross-environment file checks.

This is a realistic but limited independent testing environment, not a claim of coverage for every device or condition.

## Documentation and Implementation

The public documents have distinct roles:

- `README.md` explains the product and its principles.
- `Docs/ProductSpecification.md` is the source of truth for current user-visible behavior.
- `Docs/ARCHITECTURE.md` describes responsibility boundaries in the current source code.
- `Docs/Diagrams/` provides explanatory views of current flows at different levels of detail.

The diagrams are explanatory representations, not a separate executable specification. Future ideas are not presented as implemented features. If released behavior and documentation differ, the difference should be documented as a known limitation or corrected together with the affected source and paired Japanese/English documents. See [Documentation Scope](Docs/DOCUMENTATION_SCOPE.md).

## Product Specification

The product behavior, data flow, interaction rules, export rules, AI exchange format, and accessibility requirements are documented in:

- [Product Specification (English)](Docs/ProductSpecification.md)
- [製品仕様書（日本語）](Docs/ProductSpecification_ja.md)

## Quality and Verification

Narabi separates UI coordination from testable policies, services, loaders, engines, persistence, and rendering components. Automated unit tests cover project operations, import routing, persistence, page editing, layout, composite editing, and export-related rules.

GitHub Actions runs repository audits on Ubuntu and the `NarabiTests` unit-test target on a macOS iPhone Simulator. The latest locally verified test count, Release-build result, and verification scope are recorded in [Docs/TESTING.md](Docs/TESTING.md). These checks reduce regressions but do not claim coverage of every device, file, or operating condition.

## Help Review Translations

You do not need to build the app or edit source code to help improve a translation.

- Start with the [localization guide](Docs/Localization/README.md).
- Review the [localized app names](Docs/Localization/APP_NAMES.md).
- Check terminology and screen context in the [glossary](Docs/Localization/GLOSSARY.md).
- Read or search the current text in the [generated locale views](Docs/Localization/Generated/).
- Submit a correction or new-language proposal with the [Translation issue form](https://github.com/mexenixi/narabi/issues/new?template=translation.yml).

Natural local expression is preferred over literal translation. Suggestions from native and fluent speakers are especially helpful. Machine-assisted proposals are welcome when clearly identified. The Xcode string catalogs remain the source of truth.

### Languages not yet included are welcome

Suggestions are welcome even when a language is not currently included in Narabi. You do not need to prepare every string, build the app, edit an Xcode string catalog, or open a pull request.

Use the Translation Issue form and choose **Add a new language**. Provide the locale code, language name, regional variant if applicable, writing direction, and as much proposed wording as you can. A partial proposal, terminology review, app-name suggestion, or offer to review a future draft is also useful. Leave **Current text** blank when the locale does not yet exist, and use **Reason and usage context** to explain regional usage, tone, script, or other requirements.

The maintainer can use an accepted proposal to prepare the string-catalog entry and generated review file. Before a new locale is treated as complete, the interface strings, permission explanations, localized app name, App Store metadata, In-App Purchase names and descriptions, layout, text direction, and representative device screens should be reviewed. This staged process lets language contributors participate without needing Swift or Xcode knowledge.

## Build Notes

1. Open `Narabi.xcodeproj` in Xcode.
2. Select your own Apple Development team in **Signing & Capabilities**.
3. Confirm that the bundle identifier is available for your account.
4. Build for an iPhone or iPad target.

The repository intentionally does not include the original developer's signing team setting, certificates, provisioning profiles, or private keys.

## License

Source code is licensed under the [Apache License 2.0](LICENSE).

The names **Narabi** and **Mexenixi**, app icons, logos, screenshots, store artwork, and other brand assets are not granted under the source-code license. See [TRADEMARKS.md](TRADEMARKS.md).

## Contact

Email: `mexenixi@gmail.com`

Narabi is independently developed and operated. Messages may not be reviewed or answered, and a response cannot be guaranteed.

## Documentation

- [Product specification / 製品仕様](Docs/ProductSpecification.md)
- [Japanese product specification / 日本語製品仕様](Docs/ProductSpecification_ja.md)
- [Visual documentation / 図示資料](Docs/Diagrams/README.md)
- [Architecture](Docs/ARCHITECTURE.md)
- [Supported import formats](Docs/SUPPORTED_IMPORT_FORMATS.md)

## Verification

Build, source-audit, physical-device, print-preview, and storage verification records are maintained under [Docs](Docs/TESTING.md).
