# Changelog

## 0.8 — 2026-11-23

- ARM64 build for macOS 15+ and IsiX 6.0.8+, using IsiXPluginKit API 1.
- MIT licensing for the original implementation; retained third-party notices.
- English README, acknowledgements of Prof. Yves Gandon and collaborators,
  scientific references, EU medical-use information and publication documents.
- Ten languages, adding Turkish and Arabic to the existing eight.
- Retained control, ROI, table-cell and summary-metric tooltips; added a
  translated research-status notice and explanation in the acquisition guide.
- Retained automatic 4D grouping, TE ordering, per-level ROI handling and
  preflight checks introduced in the preceding development builds.
- Added reproducible source/release packaging and a build/test workflow.

The version increase is a publication milestone. It does not establish clinical
validation, MRQuantif equivalence or MDR conformity.

## 0.33

- Added automatic 4D viewer opening using the IsiX 6.0.8 API, group selection
  and same-image ROI snapshots. Checked header grouping with a local 4×10 example.

## 0.31–0.32

- Improved ROI order, minimum-input checks, named-ROI import and source-viewer
  close handling; migrated to Dev Kit 1.0.0 / API 1.
