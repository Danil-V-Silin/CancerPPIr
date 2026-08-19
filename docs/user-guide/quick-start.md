# Quick start

Use the qualified R 4.5.0 runtime, restore dependencies as described in the
[installation guide](installation.md), and run commands from the repository
root.

Display the CLI contract:

```bash
Rscript cancerppir.R --help
Rscript cancerppir.R --version
```

Run the synthetic example:

```bash
Rscript cancerppir.R examples/minimal_input.csv results string_cache 400 30 TRUE --case-id DEMO01
```

The result is written to:

```text
results/DEMO01/
```

The case folder must not already exist. CancerPPIr refuses to overwrite or
reuse an existing result folder. A successful run is published from a sibling
staging directory only after its outputs pass validation.
The `--case-id DEMO01` option sets a pseudonymous identifier. It determines the
local folder name and may contain 1-64 ASCII letters, digits, `.`, `_` or `-`. The
original input filename is not written to the output manifest. Omitting
`case_id` retains the legacy basename behavior and prints a privacy reminder.

During a run, progress messages report one of eight stages and elapsed time.
For an intentional rerun, use a new ID such as `DEMO01_run2` or move the
previous folder first; existing results are never overwritten implicitly.

The first STRING initialization can require substantial download time and disk space. Subsequent runs reuse the supplied cache directory.
