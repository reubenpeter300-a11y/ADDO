# ADDO Manager Premium UI — source package

Offline-first Flutter application for a single ADDO/pharmacy shop.

## Current package
- Flutter source under `lib/`.
- Premium navy / teal / gold Material 3 theme.
- SQLite offline database (schema version 5) with migration support for the current source lineage.
- Medicines, suppliers, purchases, batches, sales, expenses, customer debts and supplier payments.
- Multi-item sales cart; each cart is saved as a receipt group (`receipt_id`).
- FEFO batch allocation with expired batches excluded from sale allocation.
- Stock movement ledger and stock adjustment screen.
- Customer debt statement view and debt payment records.
- Sale returns/refunds recorded with audit and stock movement entries.
- Date-range business reports (sales, gross profit, expenses, net profit) and CSV export compatible with Excel.
- PBKDF2-HMAC-SHA256 credential hashes for newly changed credentials; existing legacy hashes are upgraded after successful login.
- Backup restore validates SQLite integrity and required tables before replacing the live database.
- `codemagic.yaml` workflow generates the missing Android platform folder, analyzes and builds a release APK.

## First login
Legacy installs created by the earlier v0.5 source may still have the documented starter credentials:
- Username: `admin`
- Password: `admin123`
- PIN: `1234`

Change the starter password and PIN immediately in Admin Security before entering real business data. Password/PIN migration to PBKDF2 happens after successful login. This source still needs a forced first-run credential setup and login lockout before production use.

## Build on Codemagic
1. Upload this project folder to a GitHub repository.
2. Add the repository in Codemagic.
3. Select the `addo-manager-android-debug` workflow from `codemagic.yaml`.
4. Run the build and download `app-release.apk` from artifacts.

The workflow currently creates a standard Android project and builds a release-mode APK. It is not configured for Play Store signing; configure a private upload key in Codemagic before distributing a production release.

## Important limitations
- Reports export CSV (Excel-readable), not native XLSX or PDF yet.
- Supplier payments are still tracked by supplier name, not allocated to a specific invoice.
- Returns are recorded and stock is restored to the medicine's aggregate quantity; add a quarantine/inspection workflow before treating returned stock as automatically saleable in regulated pharmacy operations.
- Database encryption and encrypted backups are not yet implemented.
- Forced first-run admin setup remains outstanding; login/PIN attempts are limited to five failures followed by a five-minute lockout.
- Verify local ADDO/TMDA product, recordkeeping and fiscal receipt requirements before live deployment.

## Verification status (2026-11-13)
- ZIP archive integrity and file structure checked.
- `codemagic.yaml` parsed as valid YAML; its workflow now prints Flutter, Android doctor and Java versions before resolving packages, analyzing and building.
- Source review found and corrected: batch stock not being reduced during negative stock adjustments; return-adjusted profit formula; dashboard totals after returns; backup WAL checkpoint mode; legacy-stock cost fallback; and partial-return status.
- Flutter/Dart SDK and Android SDK are not installed in the review environment. Therefore `flutter pub get`, `flutter analyze`, tests, Gradle compilation, APK generation and physical-device QA could not be run here. No APK is included in this ZIP.
- The Codemagic workflow is the next place to verify the actual Flutter/Android SDK and build. A successful build must produce `build/app/outputs/flutter-apk/app-release.apk`; download and install-test that artifact before using real pharmacy data.

Do not treat this archive as a verified production release until the remote analyze/build and device checks pass.
