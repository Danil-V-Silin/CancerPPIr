# CLI contract

```text
Rscript cancerppir.R input.csv results_dir string_cache [score_threshold] [top_n] [run_enrichment]
Rscript cancerppir.R --help
```

| Position | Argument | Requirement |
|---:|---|---|
| 1 | `input.csv` | Existing delimited input table |
| 2 | `results_dir` | Root output directory |
| 3 | `string_cache` | Local STRING cache directory |
| 4 | `score_threshold` | Optional integer from `1` to `1000`; default `400` |
| 5 | `top_n` | Optional positive integer; default `30` |
| 6 | `run_enrichment` | Optional `TRUE` or `FALSE`; default `TRUE` |

## Input preflight

The first positional argument must satisfy the
[scientific input contract](input-contract.md). Column identity is determined
from explicit recognized headers; positional fallback is not available. Raw
`pvalue`, base-2 tumor-versus-reference `logFC`, complete finite numeric values
and unique gene symbols are required. Input-contract failures return a non-zero
exit status before STRING initialization.

Exactly three to six positional arguments are accepted. Additional arguments
are rejected rather than ignored. Invalid integers, fractional values,
out-of-range thresholds, and unrecognized Boolean values produce a non-zero
exit status before network analysis begins.

The derived case folder must not already exist. CancerPPIr never overwrites or
reuses a result folder. Outputs are generated in a sibling staging directory
and atomically published only after all output and provenance checks pass.
The input basename is used only to derive the local case-folder name and is not
written to the output manifest. Use a pseudonymous basename for patient data.

`Rscript cancerppir.R --help` is the executable source of truth.
