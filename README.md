# Liver IronLoad

**Version 0.8 · Apple Silicon / ARM64 · IsiX DICOM Viewer 6.0.8 or later**

Liver IronLoad is an open-source IsiX plugin for exploring liver iron and fat
quantification from axial multi-echo GRE magnitude images. It provides named
ROIs, automatic 4D echo grouping, a results table and a draft assessment.
Image processing takes place locally.

**This release is an experimental research and comparison implementation. It
is not CE-marked as a medical device and has not completed clinical validation.
It is not released for patient diagnosis or treatment decisions.** Read
[EU medical-use information](Docs/EU_MEDICAL_USE.md) and the
[validation record](Docs/VALIDATION.md).

## Acknowledgement of Prof. Yves Gandon

We gratefully acknowledge **Professor Yves Gandon of Rennes, France**, and his
collaborators for their work on MRI-based liver iron and fat quantification
and for creating **MRQuantif**. Their scientific work and practical protocols
inspired this project's aims and ROI workflow.

This is an independent implementation, not an official MRQuantif port. No
affiliation, endorsement, certification or equivalent diagnostic performance
is claimed. See [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md) and
[REFERENCES.md](REFERENCES.md).

## Features

- Estimates of R2*, T2*, liver PDFF and exploratory liver iron concentration
  (LIC), with an explicit description of the calibration limitations.
- Guided ROI order: **L1 → L2 → L3 → M1 → M2 → S → F → N**.
- Import of named ellipses, rectangles and closed polygons from IsiX; direct
  elliptical ROI drawing in the plugin.
- Automatic grouping of eligible series into separate 4D viewers, sorted by
  echo time. A group selector switches between detected slice levels.
- Minimum-ROI and echo-quality checks that disable calculation when required
  inputs are missing or unsuitable.
- Tooltips for controls, ROI codes, table headings, cells and summary metrics.
- Ten interface languages: **German, English, French, Spanish, Italian,
  Portuguese, Japanese, Simplified Chinese, Turkish and Arabic**.
- Copyable tab-separated results and a draft assessment in the chosen language.

DICOM/PDF export to the archive is not implemented in this release.

## Requirements

- Apple Silicon Mac (ARM64), macOS 15 or later.
- IsiX DICOM Viewer **6.0.8 or later**, with plugin support. The Mac App Store
  edition does not load these plugins.
- Original, axial, classic single-frame 2D GRE magnitude DICOM images without
  fat suppression, contrast agent or lossy compression, at 1.5 T, 2.89 T or 3 T.
- At least six suitable, distinct echo times, adequate water–fat encoding and
  measurable background noise.

The plugin declares `viewer.read`, `database.read`, `viewer.4d` and `roi`.
Older hosts reject the new `viewer.4d` capability before loading the plugin.

## Install the ARM64 release

Download the ready-to-install [ARM64 plugin ZIP](Releases/Liver-IronLoad-v0.8-arm64.zip).
The checksum is in [Releases/SHA256SUMS.txt](Releases/SHA256SUMS.txt).

For GitHub Desktop setup, see [GITHUB_DESKTOP.md](GITHUB_DESKTOP.md).

1. Quit IsiX and extract `Liver-IronLoad-v0.8-arm64.zip`.
2. Open Terminal in the extracted folder and run:

   ```bash
   bash install.sh
   ```

3. Restart IsiX, open an eligible image and select **Image Filters →
   Liver IronLoad → Iron and fat …** (wording follows the selected language).

The installer verifies the signature and installs
`IsiXLeberQuant.isixplugin` into
`~/Library/Application Support/IsiX/Plugins/`. The internal bundle name is
retained so that previous Liver IronLoad builds are replaced correctly.
The installer supports an optional target folder for testing.

The supplied binary is ad hoc signed, not Developer ID notarized. macOS may
require explicit approval under its normal security settings. For public
distribution, Developer ID signing and notarization can improve installation;
see [release instructions](Docs/RELEASING.md). Do not alter the host signature.

## Measurement workflow

1. Use the acquisition information window and the original protocol documents
   to check the source acquisition. Open an echo on the desired axial level.
2. Optional: draw and name ROIs in IsiX before starting the plugin.
3. Start Liver IronLoad. The plugin searches MR series in the same study.
   Eligible echo groups open as separate 4D viewers. The group containing the
   invoked image is selected first. Choose another level with **4D echo group**.
4. Inspect every echo for motion and artifacts. Import named ROIs or draw
   ellipses in the plugin. Each slice level needs its own anatomically suitable
   ROIs; the plugin does not copy placements across different levels.
5. Supply **L1, L2, L3 and N**. Calculation remains disabled until the inputs
   pass the preflight checks. A visible message explains missing requirements.
6. Select **Calculate**, inspect the results table and fit quality, then review
   the draft assessment. The draft is not an independently validated report.

If automatic grouping is unavailable, the existing manual workflow remains:
open the matching echo series, select them under **Separate echo series**, then
use **Load viewer slice**. Already combined series can also be read through
their slices and phases.

### ROI names

| Code | Accepted examples | Purpose |
| --- | --- | --- |
| L1–L3 | Liver 1–3, Leber 1–3 | Three separate representative liver ROIs |
| M1, M2 | Muscle 1–2, Muskel 1–2 | Paraspinal reference muscle; signal ratios |
| S | Spleen, Milz, S1 | Optional spleen reference |
| P | Pancreas, Pankreas, P1 | Optional exploratory pancreas measurement |
| H | Heart, Herz, H1 | Optional signal comparison, not cardiac T2* mapping |
| F | Fat, Fett, F1 | Optional fat reference |
| N | Noise, Rauschen, N1 | Required measurable air/background noise |

Codes are language-independent. Names are case-insensitive; localized organ
names are also accepted. Avoid liver vessels, bile ducts, focal lesions and the
liver edge. Place N away from ghosting and zero-masked or cropped regions.

### How automatic 4D grouping works

Each candidate database series must contain a single echo time. Groups require
matching frame of reference, sequence, acquisition number, field strength, TR,
flip angle and full image geometry. Corresponding multi-slice volumes are
supported when their grids agree. Duplicate echo times or repeated images
make a group ambiguous and prevent its automatic opening.

At least six distinct echoes are required; phases are passed to IsiX in
ascending TE order. The plugin reuses its own matching 4D viewers while it
remains active. ROI value snapshots are associated with the same DICOM SOP
instance, not with an on-screen series number. Closing an original single-echo
window does not invalidate a separate 4D viewer. Closing the active 4D source
disables its measurement; another open group can still be selected.

Automatic grouping has been checked against a local example of 40 images:
four axial levels with ten echoes each. That example is not distributed.

## Methods and limitations

- The model uses three renormalized fat-spectrum peaks, one shared R2* and a
  fat fraction below 50%. This simplified magnitude fit is not equivalent to
  every complex-data or vendor implementation.
- Each ROI needs at least six usable echoes above twice the mean background
  signal. Additional checks reject insufficient phase encoding, ambiguous
  fractions and unreliable fits. Passing those checks is not clinical validation.
- LIC uses the published field-strength-specific coefficients of Hernando et
  al., applied here to a **different magnitude fit**. The original calibration
  was evaluated with a complex-data fit. Reported LIC is therefore exploratory.
- A combined liver LIC requires three usable liver fits and conversions.
  Extrahepatic LIC is not reported. Spleen and pancreas relaxometry is
  exploratory; the heart ROI is not a validated cardiac T2* examination.
- Muscle ROIs provide signal ratios only. MRQuantif's SIR-to-iron conversion
  and automatic switching between SIR and R2* methods are not implemented.
- Enhanced MR, mosaics, derived maps, 3D Dixon outputs and fat fractions of
  50% or more lie outside the implemented input/model scope.
- Agreement with MRQuantif, biopsy results or a local reference method has
  not been established. A new version number does not imply new validation.

See [validation details](Docs/VALIDATION.md).

## Languages and tooltips

The language selector updates the interface, tooltips, help windows, table and
assessment. The initial choice follows the system language; the user's choice
is remembered. Host errors and DICOM descriptions remain in their original
language. MR geometry, ROI coordinates and anatomical orientation are not
mirrored when Arabic is selected. Full native-speaker and layout review of
the new Turkish and Arabic translations remains pending.

## Build from source

Use Xcode command-line tools with a compatible Swift compiler and the official
[IsiXPluginKit-SDK-6.0.8.zip](https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS/releases/tag/v6.0.8).
The supplied release was built using Swift 6.4.2. No SDK binary is vendored here.

```bash
bash test.sh
bash build.sh /path/to/IsiXPluginKit-SDK-6.0.8.zip
bash scripts/package.sh
```

`build.sh` also accepts an extracted SDK directory and verifies the framework
and interface against its manifest. Output: `.build/IsiXLeberQuant.isixplugin`.
`package.sh` creates an installable ARM64 ZIP and a separate GitHub source ZIP
under `dist/`, plus SHA-256 checksums. The GitHub workflow repeats the tests and
build; it uploads artifacts but does not publish a release automatically.

## License and medical use

The original plugin code is released under the **MIT License**. MIT permits
commercial use as well as modification and redistribution, subject to its
notice requirements. Dependencies keep their own licenses; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Open-source permission is separate from medical-device compliance. For EU
clinical use, **Regulation (EU) 2017/745 (MDR)** may apply according to the
intended purpose. This release has no declared MDR conformity assessment.
Neither free distribution nor a research label establishes an exemption.
See [EU_MEDICAL_USE.md](Docs/EU_MEDICAL_USE.md).

## Contributing and publication

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md),
[CHANGELOG.md](CHANGELOG.md) and [RELEASING.md](Docs/RELEASING.md).
Do not upload identifiable DICOM data, real patient screenshots or secrets.

<img width="1348" height="765" alt="Bildschirmfoto 2026-11-24 um 12 34 57" src="https://github.com/user-attachments/assets/78dbbaf7-cd96-4515-868b-e184dde9eb53" />
<img width="1345" height="764" alt="Bildschirmfoto 2026-11-24 um 12 35 16" src="https://github.com/user-attachments/assets/cbdeb1f4-a47e-4bf5-a3bf-d0062f7732f6" />
<img width="980" height="760" alt="Bildschirmfoto 2026-11-24 um 12 35 27" src="https://github.com/user-attachments/assets/a790bfbf-4a4a-4d8f-aeb8-d7ad02fdcc04" />
