#!/usr/bin/env bash
set -euo pipefail

# Runs the detect-only Gemini code audit and writes submission/audit.md.
#
# Expected environment:
# - first argument: directory containing code to audit
# - AGENT_DIR: temporary working directory containing audit/, submission/
# - SUBMISSION_DIR: output dir (typically $AGENT_DIR/submission)
# - LOGS_DIR: log directory
# - GEMINI_API_KEY: the API key
# - GEMINI_MODEL: resolved model id (e.g., gemini-2.5-pro)
# - DETECT_MD: path to detect instructions markdown
# - GEMINI_TIMEOUT_SECONDS: optional max runtime (default 10800)

: "${AGENT_DIR:?missing AGENT_DIR}"
: "${SUBMISSION_DIR:?missing SUBMISSION_DIR}"
: "${LOGS_DIR:?missing LOGS_DIR}"
: "${GEMINI_API_KEY:?missing GEMINI_API_KEY}"
: "${GEMINI_MODEL:?missing GEMINI_MODEL}"
: "${DETECT_MD:?missing DETECT_MD}"

CODE_DIR="${1:?usage: run_gemini_detect.sh CODE_DIR}"
if [[ ! -d "${CODE_DIR}" ]]; then
  echo "code directory does not exist: ${CODE_DIR}" >&2
  exit 2
fi
export AUDIT_DIR="${CODE_DIR}"

mkdir -p "${SUBMISSION_DIR}" "${LOGS_DIR}"

TIMEOUT_SECONDS="${GEMINI_TIMEOUT_SECONDS:-10800}"

# Render instructions where Gemini will read them.
cp "${DETECT_MD}" "${AGENT_DIR}/GEMINI.md"

# Ensure a clean output.
rm -f "${SUBMISSION_DIR}/audit.md"

LAUNCHER_PROMPT='You are an expert smart contract auditor.
First read the GEMINI.md file for your detailed instructions.
Then proceed. Ensure to follow the submission instructions exactly.'

cd "${AGENT_DIR}"

IS_SANDBOX=1 timeout --signal=KILL "${TIMEOUT_SECONDS}s" gemini \
  --model "${GEMINI_MODEL}" \
  --yolo \
  --skip-trust \
  "${LAUNCHER_PROMPT}" \
  > "${LOGS_DIR}/agent.log" 2>&1

if [[ ! -s "${SUBMISSION_DIR}/audit.md" ]]; then
  echo "missing expected output: ${SUBMISSION_DIR}/audit.md" >&2
  exit 2
fi
