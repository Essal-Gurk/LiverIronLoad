# Prepared v0.8 build — 23 November 2026

Completed locally:

- Core checks: synthetic fits and failures, ROI geometry/statistics/order,
  required ROIs, DICOM screening and echo grouping.
- Localization: 186 translation keys, each complete in ten languages,
  with matching numbered placeholders and locale-selection checks.
- ARM64 compilation with Apple Swift 6.4.2, minimum deployment macOS 15.
- Official SDK 6.0.8 ZIP checksum checked; kit 1.0.0 / API 1, framework
  and ARM64 interface checksums verified against its SDK manifest.
- Bundle load and API conformance checked against the installed IsiX 6.0.8
  framework. Version, 4D capability, translations and credit/license resources
  verified in the compiled bundle.

Packaging checks cover archive integrity, a clean source archive, signature,
ARM64 architecture and repeated installation into a disposable target folder.

Not completed: live opening of the four 4D viewers, native-speaker/UI review
of the new translations, remote GitHub Actions execution, independent clinical
validation, Developer ID notarization or MDR conformity assessment.

No runtime freeze fix or diagnostic accuracy is established by these checks.
