# Third-party notices

The repository's own plugin implementation is licensed under the MIT License
in [LICENSE](LICENSE). That license does not replace third-party licenses.

## IsiXPluginKit

- Project: https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS
- Build SDK: IsiXPluginKit-SDK-6.0.8, kit 1.0.0, API 1.
- SDK revision: `97a64c7fb7ddaaa11829b86e29040674dc26844e`.
- License: GNU Lesser General Public License, version 3.
- Credits include © 2026 Thales Matheus M Santos and the upstream authors
  recorded in the SDK's original notices.

The plugin dynamically links `IsiXPluginKit.framework` provided by the user's
IsiX installation. It does not embed the SDK binary or the legacy porting kit.
The original SDK license texts and notices are retained, unchanged, in
[LICENSES/IsiXPluginKit](LICENSES/IsiXPluginKit). These notices describe the
upstream application and do not imply that all its components are bundled here.
The LGPL terms continue to apply to that library, including the applicable
rights to use an interface-compatible modified library and to debug such
modifications. No restriction in this project is intended to override them.

## IsiXPluginTemplate

- https://github.com/ThalesMMS/IsiXPluginTemplate
- MIT License; © 2026 Thales Matheus M Santos (ThalesMMS).
- The upstream MIT copyright and permission notice is retained in
  [LICENSES/IsiXPluginTemplate-MIT.txt](LICENSES/IsiXPluginTemplate-MIT.txt)
  for template-related material and development scaffolding.

## Apple frameworks

AppKit, SwiftUI and other Apple system frameworks are external runtime/build
dependencies. They are not distributed or relicensed by this project.

## Scientific references and MRQuantif

Published methods and coefficients are credited in [REFERENCES.md](REFERENCES.md).
MRQuantif is a separate program by Prof. Yves Gandon and collaborators. No
MRQuantif Java code, JAR files, images or original documentation are distributed
here. Its dependencies, such as ImageJ and PixelMed, are not plugin dependencies.
The MIT License does not grant rights to any third-party names or materials.
