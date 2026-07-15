#!/usr/bin/env bash

# Run the preserved legacy CancerPPIr implementation for all seven
# clinical reference cases.
#
# Usage:
#   bash scripts/run_legacy_baseline.sh
#
# To regenerate all outputs, including existing completed cases:
#   FORCE=1 bash scripts/run_legacy_baseline.sh

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}" || exit 1

OUTPUT_ROOT="${1:-../results/legacy_baseline_2026-07-15}"
STRING_CACHE="../string_cache"

SCORE_THRESHOLD="400"
TOP_N="30"
RUN_ENRICHMENT="TRUE"
FORCE="${FORCE:-0}"

CASE_IDS=(
  "A01"
  "K01"
  "L01"
  "M01"
  "P01"
  "P02"
  "R01"
)

INPUT_FILES=(
  "Genes_A.csv"
  "Genes_K.csv"
  "Genes_L.csv"
  "Genes_M.csv"
  "Genes_P01.csv"
  "Genes_P02.csv"
  "Genes_R.csv"
)

OUTPUT_DIRECTORIES=(
  "Genes_A"
  "Genes_K"
  "Genes_L"
  "Genes_M"
  "Genes_P01"
  "Genes_P02"
  "Genes_R"
)

EXPECTED_OUTPUTS=(
  "CancerPPIr_Analytical_Report.xlsx"
  "CancerPPIr_Technical_Report.xlsx"
  "Network_for_Cytoscape.graphml"
  "STRING_links.txt"
)

mkdir -p "${OUTPUT_ROOT}/logs"

STATUS_FILE="${OUTPUT_ROOT}/run_status.csv"
CONFIG_FILE="${OUTPUT_ROOT}/run_config.txt"

GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"

cat > "${CONFIG_FILE}" <<CONFIG
legacy_script=legacy/cancerppir_legacy.R
git_commit=${GIT_COMMIT}
score_threshold=${SCORE_THRESHOLD}
top_n=${TOP_N}
run_enrichment=${RUN_ENRICHMENT}
string_cache=${STRING_CACHE}
force=${FORCE}
CONFIG

printf '%s\n' \
  '"case_id","input_file","output_directory","start_time","end_time","exit_code","status"' \
  > "${STATUS_FILE}"

overall_status=0

for index in "${!CASE_IDS[@]}"; do
  case_id="${CASE_IDS[$index]}"
  input_file="../input/${INPUT_FILES[$index]}"
  output_directory="${OUTPUT_ROOT}/${OUTPUT_DIRECTORIES[$index]}"
  log_file="${OUTPUT_ROOT}/logs/${case_id}.log"

  if [[ ! -f "${input_file}" ]]; then
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"

    printf '"%s","%s","%s","%s","%s",%s,"%s"\n' \
      "${case_id}" \
      "${input_file}" \
      "${output_directory}" \
      "${timestamp}" \
      "${timestamp}" \
      "1" \
      "missing_input" \
      >> "${STATUS_FILE}"

    echo "[baseline] Missing input for ${case_id}: ${input_file}"
    overall_status=1
    continue
  fi

  complete=1

  for expected_file in "${EXPECTED_OUTPUTS[@]}"; do
    if [[ ! -f "${output_directory}/${expected_file}" ]]; then
      complete=0
    fi
  done

  if [[ "${FORCE}" != "1" && "${complete}" == "1" ]]; then
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"

    echo "[baseline] ${case_id}: existing complete output found; skipping."

    printf '"%s","%s","%s","%s","%s",%s,"%s"\n' \
      "${case_id}" \
      "${input_file}" \
      "${output_directory}" \
      "${timestamp}" \
      "${timestamp}" \
      "0" \
      "skipped_existing" \
      >> "${STATUS_FILE}"

    continue
  fi

  if [[ "${FORCE}" == "1" && -d "${output_directory}" ]]; then
    rm -rf "${output_directory}"
  fi

  start_time="$(date '+%Y-%m-%dT%H:%M:%S%z')"

  echo
  echo "============================================================"
  echo "[baseline] Starting ${case_id}"
  echo "[baseline] Input: ${input_file}"
  echo "============================================================"

  Rscript \
    legacy/cancerppir_legacy.R \
    "${input_file}" \
    "${OUTPUT_ROOT}" \
    "${STRING_CACHE}" \
    "${SCORE_THRESHOLD}" \
    "${TOP_N}" \
    "${RUN_ENRICHMENT}" \
    2>&1 | tee "${log_file}"

  exit_code=${PIPESTATUS[0]}
  end_time="$(date '+%Y-%m-%dT%H:%M:%S%z')"

  if [[ "${exit_code}" -eq 0 ]]; then
    run_status="completed"
    echo "[baseline] ${case_id}: completed successfully."
  else
    run_status="failed"
    echo "[baseline] ${case_id}: failed with exit code ${exit_code}."
    overall_status=1
  fi

  printf '"%s","%s","%s","%s","%s",%s,"%s"\n' \
    "${case_id}" \
    "${input_file}" \
    "${output_directory}" \
    "${start_time}" \
    "${end_time}" \
    "${exit_code}" \
    "${run_status}" \
    >> "${STATUS_FILE}"
done

echo
echo "============================================================"
echo "[baseline] Full baseline run finished."
echo "[baseline] Status file: ${STATUS_FILE}"
echo "============================================================"

exit "${overall_status}"
