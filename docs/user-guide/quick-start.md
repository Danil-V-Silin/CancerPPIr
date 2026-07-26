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

The first STRING initialization can require substantial download time and disk space. Subsequent runs reuse the supplied cache directory.
