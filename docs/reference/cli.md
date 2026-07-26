# CLI contract

```text
Rscript cancerppir.R input.csv results_dir string_cache [score_threshold] [top_n] [run_enrichment]
```

| Position | Argument | Requirement |
|---:|---|---|
| 1 | `input.csv` | Delimited input table |
| 2 | `results_dir` | Root output directory |
| 3 | `string_cache` | Local STRING cache directory |
| 4 | `score_threshold` | Optional; default `400` |
| 5 | `top_n` | Optional; default `30` |
| 6 | `run_enrichment` | Optional; default `TRUE` |

Use `Rscript cancerppir.R --help` as the executable source of truth.

A non-zero exit status indicates that the requested run did not complete successfully.
