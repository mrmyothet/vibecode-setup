#!/usr/bin/env bash
# api-setup.sh — point Claude Code + opencode at the bootcamp LLM proxy.
#   ./api-setup.sh <KEY> <PROXY_URL>
#   VIBE_KEY=sk-... VIBE_PROXY=https://<proxy> ./api-setup.sh
#   ./api-setup.sh --restore        # bring personal Claude login back
#
# TIP: `source api-setup.sh` (instead of running it) applies the config to your
# CURRENT shell immediately — no second `source ~/.zshrc` needed.
set -euo pipefail

# Detect if this script was sourced (then env exports survive into your shell).
SOURCED=0
if [ -n "${ZSH_EVAL_CONTEXT:-}" ]; then
  case "$ZSH_EVAL_CONTEXT" in *:file) SOURCED=1;; esac
elif [ -n "${BASH_SOURCE:-}" ]; then
  [ "${BASH_SOURCE[0]}" != "$0" ] && SOURCED=1
fi

# Resolve this script's path (works run or sourced, bash or zsh) for accurate hints.
if [ -n "${BASH_SOURCE:-}" ]; then
  SELF="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  SELF="$(eval 'printf %s "${(%):-%x}"')"
else
  SELF="$0"
fi
# --restore is a file op (no sourcing needed) -> always show the run-form command.
case "$SELF" in
  bash|-bash|zsh|-zsh|sh|-sh|"") SELF_CMD="bash api-setup.sh" ;;
  *)                              SELF_CMD="bash $SELF" ;;
esac

CRED="$HOME/.claude/.credentials.json"
CRED_BAK="$HOME/.claude/.credentials.json.vibe-bak"

if [ "${1:-}" = "--restore" ]; then
  [ -f "$CRED_BAK" ] && mv "$CRED_BAK" "$CRED" && echo "Restored personal Claude login." \
    || echo "No backup at $CRED_BAK."
  echo "Also remove the vibe-code-tours block from your shell profile to fully revert."
  exit 0
fi

# Auto-load a key file (beginner path: no args, just edit vibe-key.env + run).
# Looks next to the script, then in the current dir.
SELF_DIR="$(cd "$(dirname "$SELF")" 2>/dev/null && pwd || echo .)"
for KF in "$SELF_DIR/vibe-key.env" "./vibe-key.env"; do
  if [ -f "$KF" ]; then
    # shellcheck disable=SC1090
    set -a; . "$KF"; set +a
    echo "Loaded key file: $KF"
    break
  fi
done

KEY="${1:-${VIBE_KEY:-}}"
PROXY="${2:-${VIBE_PROXY:-}}"

[ -n "$PROXY" ] || { echo "ERROR: proxy URL not set. ./api-setup.sh <KEY> <PROXY_URL>" >&2; exit 1; }
case "$PROXY" in https://*) : ;; *) echo "ERROR: PROXY must start https://" >&2; exit 1;; esac
PROXY="${PROXY%/}"; PROXY="${PROXY%/v1}"   # strip trailing slash + accidental /v1

if [ -z "$KEY" ]; then printf "Paste your key (sk-...): "; read -r KEY; fi
case "$KEY" in sk-*) : ;; *) echo "ERROR: key must start sk-" >&2; exit 1;; esac

# 1. back up + remove stored Claude login (it overrides env vars)
if [ -f "$CRED" ]; then
  cp "$CRED" "$CRED_BAK"; rm -f "$CRED"
  echo "Backed up Claude login -> $CRED_BAK  (restore: $SELF_CMD --restore)"
fi

# 2. shell profile
case "${SHELL##*/}" in
  zsh)  PROFILE="$HOME/.zshrc" ;;
  bash) PROFILE="$HOME/.bashrc" ;;
  *)    PROFILE="$HOME/.profile" ;;
esac
touch "$PROFILE"
MS="# >>> vibe-code-tours >>>"; ME="# <<< vibe-code-tours <<<"
if grep -q "$MS" "$PROFILE" 2>/dev/null; then
  tmp=$(mktemp); sed "/$MS/,/$ME/d" "$PROFILE" > "$tmp" && mv "$tmp" "$PROFILE"
fi
cat >> "$PROFILE" <<EOF
$MS
# Vibe Code Tours LLM proxy
export VIBE_PROXY="$PROXY"
# Claude Code (Anthropic-compatible) — base has NO /v1
export ANTHROPIC_BASE_URL="\$VIBE_PROXY"
export ANTHROPIC_AUTH_TOKEN="$KEY"
export ANTHROPIC_API_KEY="$KEY"
# force proxy models so Claude Code never requests claude-opus-* (403)
export ANTHROPIC_MODEL="mimo-v2.5-pro"
export ANTHROPIC_SMALL_FAST_MODEL="mimo-v2.5"
# let /model picker list proxy models
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1"
# opencode / OpenAI-compatible — base HAS /v1
export OPENAI_BASE_URL="\$VIBE_PROXY/v1"
export OPENAI_API_KEY="$KEY"
vibe-model() { export OPENAI_MODEL="\$1"; echo "model: \$1"; }
$ME
EOF

# 3. opencode config file (env alone is unreliable for opencode)
OC="$HOME/.config/opencode"; mkdir -p "$OC"
cat > "$OC/opencode.json" <<OCJSON
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "vibe": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Vibe Code Tours",
      "options": { "baseURL": "$PROXY/v1", "apiKey": "$KEY" },
      "models": {
        "mimo-v2.5": { "name": "MiMo v2.5 (fast)" },
        "mimo-v2.5-pro": { "name": "MiMo v2.5 Pro (reasoning)" },
        "deepseek-flash": { "name": "DeepSeek Flash (backup)" }
      }
    }
  },
  "model": "vibe/mimo-v2.5"
}
OCJSON
echo "opencode config -> $OC/opencode.json"

# 4. live test (Anthropic /v1/messages — what Claude Code calls)
echo ""; echo "Testing key ..."
code=$(curl -s -o /tmp/vibe_t.json -w "%{http_code}" "$PROXY/v1/messages" \
  -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" \
  -d '{"model":"mimo-v2.5","max_tokens":10,"messages":[{"role":"user","content":"ok"}]}' || true)
case "$code" in
  200) echo "OK Key works." ;;
  401) echo "FAIL Key rejected (401)." >&2; exit 1 ;;
  429) echo "WARN budget/rate cap (429) — key valid." ;;
  *)   echo "WARN HTTP $code — see /tmp/vibe_t.json" ;;
esac
rm -f /tmp/vibe_t.json 2>/dev/null || true

echo ""
echo "Done. Config -> $PROFILE"
echo "Models: mimo-v2.5 (fast) · mimo-v2.5-pro (reasoning) · deepseek-flash"
echo "Switch: Claude Code  /model mimo-v2.5-pro   ·   opencode  --model vibe/mimo-v2.5-pro"
echo "Restore personal Claude login:  $SELF_CMD --restore"
echo ""
if [ "$SOURCED" = "1" ]; then
  # sourced: load the profile NOW so it is live in this shell
  # shellcheck disable=SC1090
  . "$PROFILE"
  echo "✅ Active in THIS shell. Run:  claude   (or)   opencode"
else
  echo "Activate now — copy-paste this line:"
  echo ""
  echo "    source $PROFILE"
  echo ""
  echo "(or next time: 'source api-setup.sh' to skip this step)"
  echo "Then run:  claude   (or)   opencode"
fi
