# Contributing

Contributions are welcome under the MIT License. By submitting a contribution,
you confirm that you can license it on those terms. Preserve third-party notices.

Explain the problem, resulting behavior and relevant validation in each pull
request. Run `bash test.sh` and build against the documented SDK. Changes to
fitting, thresholds, calibration or geometry need independent reference cases
and a discussion of their effects, not just tests generated from the same model.

Keep all ten translation columns complete, preserve numbered placeholders and
review tooltips alongside labels. Turkish and Arabic particularly need
native-speaker review. Do not mirror MR anatomy or change coordinate conventions.

Use synthetic or appropriately de-identified fixtures with documented rights.
Do not post patient DICOM files, identifiable screenshots, local database paths,
license credentials or signing secrets. Do not copy MRQuantif code or figures
without explicit compatible permission.

Validation results and clinical claims must be distinguished. Changes must not
present this experimental release as a certified medical device.
