# GitHub Desktop: publish the complete package

This folder is the repository root. It contains the English README, source,
MIT License, acknowledgements of Prof. Yves Gandon, EU medical-use information
and a ready-to-install ARM64 ZIP in `Releases/`.

## Add the prepared repository

1. Extract `LiverIronLoad-v0.8-GitHub-Complete.zip` completely. Do not select
   the ZIP itself or the `.isixplugin` bundle in GitHub Desktop.
2. In GitHub Desktop choose **File → Add Local Repository…**.
3. Choose the extracted **LiverIronLoad** folder. The package includes its Git
   metadata, so it is already a Git repository. Hidden items must be preserved
   when extracting; do not copy only the visible files to a different folder.
4. Select **Publish repository**. Review the account, repository name,
   description and visibility before publishing. An open-source license alone
   does not make a private repository publicly visible.

The original local repository used to prepare this package is already named
`LiverIronLoad` in GitHub Desktop. If using that entry, do not add a second
downloaded copy: it already contains the prepared project files.

## When adding files to another existing repository

Copy the visible project files and `Releases/` into that repository's root.
Preserve its own `.git` directory; do not copy a nested `.git` directory over
it. Commit the changes in GitHub Desktop, then push. The prepared `.gitignore`
explicitly permits the release ZIP under `Releases/`.

## What belongs where

- `README.md`: English project overview and install/build instructions.
- `Sources/`, `Tests/`, `Resources/`: unpacked, reviewable source code.
- `Releases/Liver-IronLoad-v0.8-arm64.zip`: complete installation archive.
- `ACKNOWLEDGEMENTS.md`: thanks to Prof. Yves Gandon and collaborators.
- `LICENSE`, `LICENSES/`, `THIRD_PARTY_NOTICES.md`: license information.
- `Docs/EU_MEDICAL_USE.md`: EU medical-use and validation limitations.

The package was prepared locally. It has no configured GitHub remote and has
not been published by the preparation process. No patient data or signing keys
are included. Git commit authorship follows the existing local repository.
