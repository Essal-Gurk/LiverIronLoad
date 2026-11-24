# Validation record and remaining work

## Automated checks available in the source tree

`bash test.sh` checks:

- Synthetic magnitude fits, failure cases and the implemented LIC arithmetic.
- ROI shapes, overlap, signal statistics, required regions and guided order.
- Classic DICOM header parsing and rejection of unsupported sources.
- Four-group/ten-echo planning, ascending TE order, duplicate-TE rejection,
  geometry mismatches and corresponding multi-slice volumes.
- All translation rows in ten languages, nonempty values, matching numbered
  placeholders, system-language selection and number formatting.

These tests check implementation behavior, not independent clinical accuracy.
Synthetic data generated from the same model cannot validate that model.

## Local source-header comparison

The v0.33 planner was run on a local dataset containing 40 original images and
identified four separate axial groups of ten echoes. No images, original
identifiers, patient details or filesystem paths are included here. An optional
`Tests/RealGroupingChecks.swift` runner can repeat that shape-specific check on
an authorized local manifest; it is not part of the public CI fixtures.

## Version 0.8 release checks

The release process runs the core suite, compiles an ARM64 bundle, verifies its
signature, tests installation and replacement in a temporary directory and
checks bundle loading against an installed IsiX 6.0.8 framework when available.
Actual outcomes for this prepared release are recorded in
[BUILD_VALIDATION.md](BUILD_VALIDATION.md).

## Outstanding application and clinical validation

- Exercise the full automatic four-viewer opening workflow in a running IsiX
  instance, including phase ordering and repeated invocation.
- Reproduce copying ROIs and closing original/4D viewers while the plugin is
  open. The previously reported hang has not been conclusively diagnosed.
- Independently compare identical ROIs against MRQuantif and a documented
  reference implementation over the relevant fat/iron range and protocols.
- Assess movement, noise, fat–water ambiguity and rapid-decay failure cases
  using independently characterized data.
- Obtain native-speaker review and visual inspection of all translations,
  particularly Turkish and Arabic. The Arabic interface retains the image
  and table coordinate conventions rather than mirroring anatomy.
- Complete any clinical and regulatory work required for the intended use.

No clinical equivalence, sensitivity, specificity or regulatory clearance is
claimed by this release.
