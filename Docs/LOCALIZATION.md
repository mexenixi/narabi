# Localization

Narabi keeps translation responsibilities separated by where the text is delivered.

## App UI

`Narabi/Localizable.xcstrings` contains short in-app labels, buttons, progress text, results, errors, and accessibility text. Keys use feature prefixes such as `common.*`, `import.progress.*`, `import.result.*`, `export.*`, `ai.*`, `support.*`, and `legal.*`. Developer comments explain where new or ambiguous keys appear.

## System permission prompts

`Narabi/InfoPlist.xcstrings` contains camera, photo-library, and other system permission descriptions.

## Bundled legal documents

`Narabi/Legal/` contains the Japanese and English privacy policy and terms used inside the app. Japanese is used for Japanese; English is the document fallback for other app languages until another complete legal translation is intentionally added.

## Website links

The app opens shared canonical website URLs. It does not choose a website language from the app language. The static website is responsible for choosing Japanese or English from the visitor's browser preference and any explicit website language choice. The website currently publishes Japanese and English only.

## App Store and in-app purchase metadata

App Store listing text and StoreKit product names/descriptions are localized in App Store Connect. App-side labels do not replace that metadata.

## Internal identifiers

Accessibility identifiers, product identifiers, file names, and localization keys are stable internal identifiers and are not translated.

## Adding or changing text

1. Choose the correct feature prefix.
2. Add all supported app languages in the String Catalog.
3. Add a developer comment describing the screen and parameters.
4. Localize the complete sentence where word order or plural behavior differs.
5. Run `python3 Scripts/audit_localization_references.py` and `bash Scripts/audit_all.sh`.
6. Review the result in the affected app language. Do not rely on a Japanese fallback as a translation.

## Fallback policy

Unknown app languages fall back to English. The website independently selects Japanese or English from browser preferences. Translations should be natural for each language rather than literal copies of Japanese wording.

## Support message groups
Support-purchase text is grouped so future language-specific writing is easy to locate:
- `support.language.*`: the Support page's independent language control
- `support.product.*`: the three existing product names
- `support.status.*` and existing `support.*` status keys: loading, pending, success, and errors
- `support.message.small.*`, `support.message.medium.*`, `support.message.large.*`: random post-purchase messages
- `support.history.*`: the purchase-message list and language filter

The Support page defaults to `Follow App Language`, meaning Narabi's effective in-app language, not a fresh lookup of the device's first preferred language. Message history stores the displayed message, date, language code, and product ID locally. It does not store price, transaction ID, completion counts, or collection progress. All 21 support-message language packs are independently authored. They are not translations of one shared source; meaning, tone, imagery, and humor may differ by language.

## Public-link button labels
The in-app labels that open the product, support, privacy, terms, and Japanese commercial-disclosure web pages are grouped as `info.product`, `info.support`, `info.privacy`, `info.terms`, and `info.commercial`. These labels are localized in all app languages. The destination website remains a Japanese/English website and chooses its own display language.

## Optional support purchase localization

- Support messages use `support.message.small.*`, `support.message.medium.*`, and `support.message.large.*`.
- All 21 language packs contain three independently authored messages for each of the three products, for a total of 189 messages.
- The messages are not translations of one shared source. Meaning, tone, imagery, and humor may differ by language.
- `support.language.*` controls the language selector on the support page. The default follows Narabi's currently effective app language, not a separate device-language lookup.
- `support.history.*` controls the message-history screen and its all/language filter.
- App Store purchase-sheet product names and descriptions are localized separately in App Store Connect.

A purchase does not change editing features, storage capacity, usage restrictions, support priority, or any other practical capability. After purchase, one of three thank-you messages for the selected Support-page language and product is shown at random, and the message text and received date are stored locally on the device. Each of the three messages has an equal chance of being selected and has no different functional or monetary value.

<!-- NARABI-PRIVACY-CANONICAL:BEGIN -->
The privacy policy published on the website is canonical. `Narabi/Legal/Privacy_ja.md` and `Narabi/Legal/Privacy_en.md` are synchronized offline-reading copies and must not be edited as independent source documents.
<!-- NARABI-PRIVACY-CANONICAL:END -->
