# Leadership desktop UX requirements

Source: the user's eight-row principal UX findings and request dated 16 October 2026. This document fixes the scope for the implementation plan beside it.

## Outcome

Make the existing desktop web application easier to navigate and more productive for Principal and Coordinator. Keep the existing features; remove duplication and confusing presentation. Principal and Coordinator share non-finance functionality. Finance is Principal-only, including the Fees module, finance metrics, payment verification, finance search results, finance report generation, exports and downloads.

## Requirements

1. Overview: one summary per subject, a small set of direct task actions, no repeated media navigation panel or repeated collection chart/value.
2. Navigation: module/tab URLs, Back/Forward, reload and bookmarking work. Preserve module filters, pagination and selected class while switching modules. Isolate state between accounts, roles and branches.
3. Attention: display actual pending work supported by existing API fields. Do not call configured classes or zero inquiries urgent. Do not imply inquiry follow-up status if the backend has no such status.
4. Finance: reconcile the observed ₹40,000 collection difference; consume one existing authoritative summary contract consistently. Preserve historical receipts and financial records.
5. Labels: consistent sidebar/search/page names; one main title; one active-view refresh action. Exports/follow-up must not be hidden under payment settings.
6. Desktop: prioritise 1366×768 and 1440×1000, with a regression check at 1920×1080. Put daily actions above the fold, essential directory columns/actions within available width, and retain readable text.
7. Media: one status label per card, one set of count-bearing filters, upload on demand, truthful photo/video controls. Preserve existing media and publication behaviour.
8. Reports: group current reports into Academic and Finance; expose all returned export history through pagination; keep report scope and finance restrictions clear.
9. Role parity: both roles receive the shared non-finance UI and full existing Public Website workflows: media library, homepage copy and news ticker. Coordinator remains limited to the assigned branch under existing backend authorisation. Do not grant cross-branch access.
10. Keep Flutter source/builds, shared backend contracts, database schema, existing unrelated edits, and public SEO intact. No new business modules, real test payments, production account resets, publishing, deployment or GitHub changes are part of plan preparation.

## Evidence and limits

The read-only audit inspected the local production build against real Miyapur backend reads at two desktop sizes. Overview showed ₹15,66,000 / 47%; Fees showed ₹16,06,000 / 48%. The dashboard reads invoice-based summary data; Fees independently sums payment rows. The exact financial reason for the ₹40,000 delta remains to be reconciled before implementation is accepted.

Coordinator live browser verification is outstanding because a working account/session was not available. Source permits the same non-finance module list, but the current client renders ticker-only website management for Coordinator. The backend website handler currently checks leadership for copy/gallery too, despite an outdated restrictive comment; deployed behaviour still needs verification.

The current backend assigns Coordinator to its own branch. The user's role-parity requirement is applied to features and workflow, without treating it as permission to broaden organisational scope.
