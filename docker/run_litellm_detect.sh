#!/usr/bin/env bash
set -euo pipefail

# Runs the detect-only LiteLLM audit and writes submission/audit.md.
#
# LiteLLM reuses the Codex CLI, but instead of talking to OpenAI it talks to a
# LiteLLM proxy (an OpenAI-compatible endpoint). This is wired up through a
# custom Codex "model provider" that points at ${LITELLM_BASE_URL} and reads the
# key from ${LITELLM_API_KEY}. See the Codex <-> LiteLLM integration guide.
#
# Expected environment:
# - first argument: directory containing code to audit
# - AGENT_DIR: temporary working directory containing audit/, submission/
# - SUBMISSION_DIR: output dir (typically $AGENT_DIR/submission)
# - LOGS_DIR: log directory
# - LITELLM_API_KEY: the LiteLLM API key
# - LITELLM_MODEL: resolved model id (any model served by the LiteLLM proxy)
# - LITELLM_BASE_URL: OpenAI-compatible base URL (default https://litellm.nethermind.dev/v1)
# - DETECT_MD: path to detect instructions markdown
# - LITELLM_WIRE_API: optional Codex wire protocol, "chat" (default) or "responses"
# - LITELLM_TIMEOUT_SECONDS: optional max runtime (default 10800)

: "${AGENT_DIR:?missing AGENT_DIR}"
: "${SUBMISSION_DIR:?missing SUBMISSION_DIR}"
: "${LOGS_DIR:?missing LOGS_DIR}"
: "${LITELLM_API_KEY:?missing LITELLM_API_KEY}"
: "${LITELLM_MODEL:?missing LITELLM_MODEL}"
: "${DETECT_MD:?missing DETECT_MD}"

LITELLM_BASE_URL="${LITELLM_BASE_URL:-https://litellm.nethermind.dev/v1}"
LITELLM_WIRE_API="${LITELLM_WIRE_API:-chat}"

CODE_DIR="${1:?usage: run_litellm_detect.sh CODE_DIR}"
if [[ ! -d "${CODE_DIR}" ]]; then
  echo "code directory does not exist: ${CODE_DIR}" >&2
  exit 2
fi
export AUDIT_DIR="${CODE_DIR}"

mkdir -p "${SUBMISSION_DIR}" "${LOGS_DIR}"

# Keep runaway audits bounded by default.
TIMEOUT_SECONDS="${LITELLM_TIMEOUT_SECONDS:-10800}"
if ! [[ "${TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "invalid LITELLM_TIMEOUT_SECONDS=${TIMEOUT_SECONDS}" >&2
  exit 2
fi

# Render instructions where Codex will read them.
cp "${DETECT_MD}" "${AGENT_DIR}/AGENTS.md"

# Ensure a clean output.
rm -f "${SUBMISSION_DIR}/audit.md"

LAUNCHER_PROMPT='You are an expert smart contract auditor.
First read the AGENTS.md file for your detailed instructions.
Then proceed. Ensure to follow the submission instructions exactly.'

# Configure Codex to use the LiteLLM endpoint as a custom model provider.
# Codex reads this from $CODEX_HOME/.codex, and HOME == AGENT_DIR here, so the
# config lives at $AGENT_DIR/.codex/config.toml. The key is read from the env
# var named by `env_key`, so no `codex login` step is required.
CODEX_CONFIG_DIR="${AGENT_DIR}/.codex"
mkdir -p "${CODEX_CONFIG_DIR}"
cat > "${CODEX_CONFIG_DIR}/config.toml" <<EOF
model_provider = "litellm"

[model_providers.litellm]
name = "LiteLLM"
base_url = "${LITELLM_BASE_URL}"
env_key = "LITELLM_API_KEY"
wire_api = "${LITELLM_WIRE_API}"
EOF

cd "${AGENT_DIR}"

timeout --signal=KILL "${TIMEOUT_SECONDS}s" codex exec \
  --model "${LITELLM_MODEL}" \
  -c model_provider="litellm" \
  --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check \
  --experimental-json \
  "${LAUNCHER_PROMPT}" \
  > "${LOGS_DIR}/agent.log" 2>&1

if [[ ! -s "${SUBMISSION_DIR}/audit.md" ]]; then
  echo "missing expected output: ${SUBMISSION_DIR}/audit.md" >&2
  exit 2
fi
