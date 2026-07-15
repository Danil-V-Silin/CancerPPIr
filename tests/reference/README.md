# CancerPPIr reference data

This directory stores baseline metadata and reference outputs generated
with the preserved legacy implementation of CancerPPIr.

The reference data are used to:

- compare legacy and refactored analytical results;
- identify unintended changes in calculations;
- test reproducibility across software environments;
- document expected workflow behavior.

Directory structure:

- `environment/` — R, package, input-file and STRING-resource manifests;
- `R01/` — reference outputs for clinical case R01;
- `K01/` — reference outputs for clinical case K01;
- `P01/` — reference outputs for clinical case P01.

Raw clinical input data and large STRING cache files must not be committed
to the repository.
