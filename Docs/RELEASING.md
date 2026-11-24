# Publishing version 0.8 on GitHub

The supplied source archive is ready to become a repository. No GitHub
repository, account name or remote URL is assumed by these instructions.
No upload or publication has been performed as part of preparing the package.

## Source repository

1. Extract `Liver-IronLoad-v0.8-source.zip`. Use the contents of its top-level
   directory as the repository root. In GitHub's license selector choose MIT
   only if creating a license separately; the supplied `LICENSE` is already MIT.
2. Keep `LICENSE`, `ACKNOWLEDGEMENTS.md`, `REFERENCES.md`,
   `THIRD_PARTY_NOTICES.md` and `LICENSES/` with the source.
3. Review [EU_MEDICAL_USE.md](EU_MEDICAL_USE.md) and the validation record. Do
   not describe the plugin as CE-marked, clinically validated or equivalent to
   MRQuantif. The MIT copyright permission is not a medical authorization.
4. Inspect the staged files for patient data, original DICOMs, screenshots,
   local manifests, credentials and signing material before committing.
   `.gitignore` excludes common artifacts; it does not inspect their contents.
5. Add the actual repository URL to `CITATION.cff` if desired. Enable private
   vulnerability reporting and choose repository visibility in GitHub settings.

## Build and package

```bash
bash test.sh
bash build.sh "$(bash scripts/fetch-sdk.sh)"
bash scripts/package.sh
```

`fetch-sdk.sh` downloads the official 6.0.8 SDK and checks its pinned ZIP
SHA-256. `build.sh` verifies the framework/interface checksums too. The SDK
binary is kept only under `.build/`; neither package includes it.

The workflow in `.github/workflows/build.yml` can be started manually. It
requires an ARM64 macOS runner with Xcode 27.2+ / a compatible Swift toolchain.
It stops clearly if the required Xcode is unavailable. Public runner toolchain
availability and execution of the remote workflow have not been verified.
It uploads build artifacts; it does not create a release or publish code.

## GitHub release

Create a `v0.8` tag and a prerelease, using the v0.8 section of
`CHANGELOG.md`. Attach the ARM64 installation ZIP and checksum file from
`dist/`. Source can be downloaded from the repository/tag or from the prepared
source ZIP. State that it requires macOS 15+ and IsiX 6.0.8+ and remains an
experimental, non-CE-marked implementation.

The prebuilt plugin is ad hoc signed. Developer ID signing and Apple
notarization, if arranged by the maintainer, must happen before packaging and
checksum generation. Never ship a signing identity or private key. If a bundle
is re-signed after packaging, recreate the archive and checksums.
