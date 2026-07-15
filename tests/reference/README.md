# CancerPPIr reference data

This directory stores baseline metadata and reference outputs generated
with the preserved legacy implementation of CancerPPIr.

The reference data are used to:

- compare legacy and refactored analytical results;
- identify unintended changes in calculations;
- test reproducibility across software environments;
- document expected workflow behavior.

The full clinical baseline includes seven cases:

- `A01` — generated from `Genes_A.csv`;
- `K01` — generated from `Genes_K.csv`;
- `L01` — generated from `Genes_L.csv`;
- `M01` — generated from `Genes_M.csv`;
- `P01` — generated from `Genes_P01.csv`;
- `P02` — generated from `Genes_P02.csv`;
- `R01` — generated from `Genes_R.csv`.

`Genes_Ar.csv` and `Genes_A2r.csv` are excluded from the reference baseline.

Directory structure:

- `environment/` — R, package, input-file and STRING-resource manifests;
- `A01/`, `K01/`, `L01/`, `M01/`, `P01/`, `P02/`, and `R01/`
  — reference outputs for the corresponding clinical cases.

Raw clinical input data and large STRING cache files must not be committed
to the repository.
