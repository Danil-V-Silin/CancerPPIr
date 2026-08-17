# Quick start

Run commands from the repository root.

Display the CLI contract:

```bash
Rscript cancerppir.R --help
```

Run the synthetic example:

```bash
Rscript cancerppir.R examples/minimal_input.csv results string_cache 400 30 TRUE
```

The result is written to:

```text
results/minimal_input/
```

The case folder must not already exist. CancerPPIr refuses to overwrite or
reuse an existing result folder. A successful run is published from a sibling
staging directory only after its outputs pass validation.
The original input filename is not written to the output manifest. It still
determines the local folder name, so patient files should use pseudonymous
basenames.

The first STRING initialization can require substantial download time and disk space. Subsequent runs reuse the supplied cache directory.
