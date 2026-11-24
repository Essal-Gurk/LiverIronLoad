# Scientific and technical references

These references describe original research, source protocols and host software.
They are scientific credit, not evidence that this plugin reproduces their
results or has inherited their validation.

1. **Gandon Y, Olivié D, Guyader D, et al.** Non-invasive assessment of hepatic
   iron stores by MRI. *Lancet*. 2004;363(9406):357–362.
   [DOI: 10.1016/S0140-6736(04)15436-6](https://doi.org/10.1016/S0140-6736(04)15436-6).
   Foundational work; the plugin does not implement the complete SIR method.
2. **Prof. Yves Gandon and collaborators. MRQuantif.**
   [Website](https://radsapp.net/mrquantif),
   [protocols](https://radsapp.net/mrquantif/protocols),
   [author information](https://radsapp.net/mrquantif/about.html).
3. **Orcel T, Chau HT, Turlin B, et al.** Evaluation of proton density fat
   fraction (PDFF) obtained from a vendor-neutral MRI sequence and MRQuantif
   software. *European Radiology*. 2023;33:8999–9009.
   [DOI: 10.1007/s00330-023-09798-4](https://doi.org/10.1007/s00330-023-09798-4).
   This evaluates MRQuantif, not Liver IronLoad.
4. **Hernando D, Zhao R, Yuan Q, et al.** Multicenter Reproducibility of Liver
   Iron Quantification with 1.5-T and 3.0-T MRI. *Radiology*.
   [DOI: 10.1148/radiol.213256](https://doi.org/10.1148/radiol.213256).
   Source of field-dependent calibration coefficients. Their use with this
   different magnitude fit remains exploratory.
5. **Hamilton G, Yokoo T, Bydder M, et al.** In vivo characterization of the
   liver fat 1H MR spectrum. *NMR in Biomedicine*. 2011.
   [DOI: 10.1002/nbm.1622](https://doi.org/10.1002/nbm.1622).
   Fat-spectrum reference; this plugin uses a simplified three-peak model.
6. **ESGAR/SAR.** Quantification of Liver Iron Overload with MRI: Review and
   Guidelines from the ESGAR and SAR. *Radiology*. 2023.
   [DOI: 10.1148/radiol.221856](https://doi.org/10.1148/radiol.221856).
7. **IsiX DICOM Viewer / IsiXPluginKit**, Thales Matheus M Santos and upstream
   contributors. [Host repository](https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS),
   [plugin template](https://github.com/ThalesMMS/IsiXPluginTemplate).

Regulatory references are listed separately in
[EU_MEDICAL_USE.md](Docs/EU_MEDICAL_USE.md).
