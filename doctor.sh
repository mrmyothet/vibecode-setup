#!/usr/bin/env bash
# Vibe Code Bootcamp — ch-0 doctor
#
# Runs environment diagnostic and produces a shareable report card to drop in
# the Discord channel #ch-0-intro. Instructor reacts ✅ to award the ch-0-done
# role, which unlocks #ch-1.
#
# Stages:
#   1. detect platform (mac | wsl | linux)
#   2. detect claude install location (linux | windows | both | none)
#      — if both → prompt REPLACE (recommended) | KEEP | SKIP
#   3. run version checks (node, npm, python, git, gh, claude)
#   4. probe gh auth + user + read access
#   5. probe claude proxy with `claude -p "ping"` (or curl fallback)
#   6. ask claude to render results as SVG badge card
#   7. svg → png via rsvg-convert / convert / chromium / text fallback
#   8. print path + drop-in instructions for #ch-0-intro
#
# Flags:
#   --non-interactive   default to REPLACE if claude install conflict found
#   --keep              keep windows-native claude (skip the prompt)
#   --replace           force replace (skip the prompt)
#   --out DIR           output dir for artifacts (default: ~/.vibecode/doctor)
#   --no-claude         skip claude-rendered card (use static template)
#
# Exit codes:
#   0  all green
#   1  hard failure (no node, no shell tools)
#   2  soft fail (claude/proxy down; instructor /unlock path)

set -u

# ---------- args ----------
NONINT=0; KEEP=0; REPLACE=0; OUTDIR="${HOME}/.vibecode/doctor"; NO_CLAUDE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --non-interactive) NONINT=1 ;;
    --keep)            KEEP=1 ;;
    --replace)         REPLACE=1 ;;
    --no-claude)       NO_CLAUDE=1 ;;
    --out)             OUTDIR="$2"; shift ;;
    -h|--help)
      sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

mkdir -p "$OUTDIR"
TS="$(date +%Y%m%d-%H%M%S)"
JSON="$OUTDIR/results-$TS.json"
MD="$OUTDIR/report-$TS.md"
SVG="$OUTDIR/report-$TS.svg"
PNG="$OUTDIR/report-$TS.png"
TXT="$OUTDIR/report-$TS.txt"

# ---------- ui ----------
c_reset=$'\033[0m'; c_dim=$'\033[2m'
c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_bold=$'\033[1m'
ok()   { printf '  %s✅%s %s\n' "$c_ok"   "$c_reset" "$*"; }
warn() { printf '  %s⚠ %s%s\n'  "$c_warn" "$c_reset" "$*"; }
fail() { printf '  %s❌%s %s\n' "$c_err"  "$c_reset" "$*"; }
hr()   { printf '%s──────────────────────────────────────────────%s\n' "$c_dim" "$c_reset"; }
say()  { printf '%s%s%s\n' "$c_bold" "$*" "$c_reset"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- 1. detect platform ----------
PLATFORM=linux
if [ "$(uname -s)" = "Darwin" ]; then PLATFORM=mac
elif grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then PLATFORM=wsl
fi

say "Vibe Code Doctor"; hr
echo "  platform: $PLATFORM"

# ---------- 2. detect claude location ----------
CLAUDE_LINUX=""; CLAUDE_WIN=""; CLAUDE_LOC=none
if have claude; then
  bin="$(command -v claude)"
  case "$bin" in
    /mnt/c/*|*/AppData/*|*.exe|*.cmd) CLAUDE_WIN="$bin"; CLAUDE_LOC=windows ;;
    *)                                CLAUDE_LINUX="$bin"; CLAUDE_LOC=linux ;;
  esac
fi
# WSL: peek windows claude even when linux claude is on PATH first.
if [ "$PLATFORM" = "wsl" ]; then
  for p in "/mnt/c/Users/$USER/AppData/Roaming/npm/claude.cmd" \
           "/mnt/c/Program Files/nodejs/claude.cmd" \
           "$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')\\AppData\\Roaming\\npm\\claude.cmd" 2>/dev/null)"; do
    [ -n "$p" ] && [ -f "$p" ] && { CLAUDE_WIN="$p"; break; }
  done
  if [ -n "$CLAUDE_LINUX" ] && [ -n "$CLAUDE_WIN" ]; then CLAUDE_LOC=both
  elif [ -n "$CLAUDE_WIN" ] && [ -z "$CLAUDE_LINUX" ]; then CLAUDE_LOC=windows
  fi
fi
echo "  claude:   $CLAUDE_LOC${CLAUDE_LINUX:+  linux=$CLAUDE_LINUX}${CLAUDE_WIN:+  win=$CLAUDE_WIN}"
hr

# ---------- 2b. conflict resolution ----------
CHOICE=skip
if [ "$CLAUDE_LOC" = "both" ]; then
  warn "windows-native claude AND wsl claude both installed — config drift risk"
  echo "    cohort recommends WSL-native only (single home, single config)"
  if [ "$REPLACE" = "1" ] || [ "$NONINT" = "1" ]; then CHOICE=replace
  elif [ "$KEEP" = "1" ]; then CHOICE=keep
  else
    echo
    echo "    [R] REPLACE — uninstall windows, install in WSL (recommended)"
    echo "    [K] KEEP    — leave windows, route proxy to Windows .claude/"
    echo "    [S] SKIP    — keep both, accept risk (instructor manually unlocks)"
    printf "    pick [R/K/S] (default R): "
    read -r ans
    case "${ans:-R}" in
      r|R) CHOICE=replace ;;
      k|K) CHOICE=keep ;;
      *)   CHOICE=skip ;;
    esac
  fi
  echo "    choice: $CHOICE"
  case "$CHOICE" in
    replace)
      echo "    uninstalling windows-native claude…"
      if have powershell.exe; then
        powershell.exe -NoProfile -Command "npm uninstall -g @anthropic-ai/claude-code" 2>/dev/null || warn "powershell uninstall returned non-zero"
      elif have cmd.exe; then
        cmd.exe /c "npm uninstall -g @anthropic-ai/claude-code" 2>/dev/null || warn "cmd uninstall returned non-zero"
      else
        warn "no powershell/cmd on PATH — uninstall windows claude manually:"
        echo "      (in Windows) npm uninstall -g @anthropic-ai/claude-code"
      fi
      CLAUDE_WIN=""
      CLAUDE_LOC=linux
      ;;
    keep)
      ok "keeping windows claude (proxy config will target Windows .claude/)"
      ;;
    skip)
      warn "skip — both installs left in place. ch-0 evidence still works but config drift risk remains."
      ;;
  esac
fi

# ---------- 3. version checks ----------
say "Versions"; hr
checks_pass=0; checks_total=0
# Writes status line to stderr (so $() doesn't swallow it), echoes "ok"/"fail" on stdout.
# Caller updates counters outside the subshell.
record_check() {
  local name="$1" cmd="$2" want="$3"
  local out
  if out="$($cmd 2>&1)" && echo "$out" | grep -qE "$want"; then
    printf '  \033[32m✅\033[0m %s: %s\n' "$name" "$(echo "$out" | head -1)" >&2
    echo "ok"
  else
    printf '  \033[31m❌\033[0m %s: %s\n' "$name" "${out:-<missing>}" >&2
    echo "fail"
  fi
}
score_check() { checks_total=$((checks_total+1)); [ "$1" = "ok" ] && checks_pass=$((checks_pass+1)); }

NODE_R=$(record_check "node"   "node --version"     "^v(22|23|24)\.");           score_check "$NODE_R"
NPM_R=$(record_check  "npm"    "npm --version"      "^(1[0-9]|2[0-9])\.");        score_check "$NPM_R"
PY_R=$(record_check   "python" "python3 --version"  "^Python 3\.(12|13|14)\.");  score_check "$PY_R"
GIT_R=$(record_check  "git"    "git --version"      "git version 2\.");           score_check "$GIT_R"
GH_R=$(record_check   "gh"     "gh --version"       "gh version (2\.[4-9][0-9]|[3-9])"); score_check "$GH_R"
CL_R=$(record_check   "claude" "claude --version"   "^[0-9]");                     score_check "$CL_R"

# ---------- 4. gh auth + user + read probe ----------
say "GitHub"; hr
GH_USER=""; GH_AUTH=fail; GH_PR=fail
if have gh && gh auth status >/dev/null 2>&1; then
  GH_AUTH=ok
  GH_USER="$(gh api user --jq .login 2>/dev/null || true)"
  if [ -n "$GH_USER" ]; then ok "auth: $GH_USER"; else warn "auth: ok but /user empty"; fi
  if gh pr list --repo cli/cli --limit 1 >/dev/null 2>&1; then GH_PR=ok; ok "pr read probe (cli/cli)"
  else fail "pr read probe — token may lack repo scope"
  fi
else
  fail "gh not logged in (run: gh auth login)"
fi

# ---------- 5. claude proxy probe ----------
say "Claude API"; hr
CL_API=fail; CL_REPLY=""
if have claude; then
  if CL_REPLY="$(claude -p "ping in one word" --output-format text 2>&1)" && [ -n "$CL_REPLY" ] && ! echo "$CL_REPLY" | grep -qiE "error|401|403|fetch failed|ENOTFOUND"; then
    CL_API=ok; ok "claude -p ping: $(echo "$CL_REPLY" | head -1 | cut -c1-60)"
  else
    fail "claude -p failed: $(echo "$CL_REPLY" | head -1 | cut -c1-100)"
  fi
else
  fail "claude not installed"
fi

# ---------- 6. write JSON ----------
cat > "$JSON" <<EOF
{
  "ts": "$TS",
  "platform": "$PLATFORM",
  "claude_loc": "$CLAUDE_LOC",
  "claude_choice": "$CHOICE",
  "gh_user": "$GH_USER",
  "checks": {
    "node": "$NODE_R", "npm": "$NPM_R", "python": "$PY_R",
    "git": "$GIT_R", "gh": "$GH_R", "claude": "$CL_R"
  },
  "gh": { "auth": "$GH_AUTH", "pr_probe": "$GH_PR" },
  "claude_api": "$CL_API",
  "score": "$checks_pass/$checks_total"
}
EOF
ok "results json: $JSON"

# ---------- 7. render card ----------
# Try claude → svg. If it fails or --no-claude, use static svg template.
render_static_svg() {
  local user="${GH_USER:-anonymous}" score="$checks_pass/$checks_total"
  local cl_badge="✅"; [ "$CL_API" = "fail" ] && cl_badge="❌"
  local gh_badge="✅"; [ "$GH_AUTH" = "fail" ] && gh_badge="❌"
  cat > "$SVG" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="450" viewBox="0 0 800 450">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#fef3e2"/>
      <stop offset="1" stop-color="#fde2c4"/>
    </linearGradient>
  </defs>
  <rect width="800" height="450" fill="url(#bg)"/>
  <rect x="20" y="20" width="760" height="410" fill="none" stroke="#d97706" stroke-width="3" rx="18"/>
  <text x="50" y="80" font-family="ui-monospace,monospace" font-size="32" font-weight="700" fill="#7c2d12">🎓 Vibe Code Doctor</text>
  <text x="50" y="120" font-family="ui-monospace,monospace" font-size="20" fill="#9a3412">@${user}</text>
  <text x="50" y="170" font-family="ui-monospace,monospace" font-size="18" fill="#1f2937">platform: ${PLATFORM}   claude: ${CLAUDE_LOC}</text>
  <text x="50" y="210" font-family="ui-monospace,monospace" font-size="18" fill="#1f2937">node ${NODE_R}   npm ${NPM_R}   python ${PY_R}</text>
  <text x="50" y="240" font-family="ui-monospace,monospace" font-size="18" fill="#1f2937">git ${GIT_R}   gh ${GH_R}   claude ${CL_R}</text>
  <text x="50" y="290" font-family="ui-monospace,monospace" font-size="22" fill="#7c2d12">${gh_badge} github: ${GH_USER:-not-authed}</text>
  <text x="50" y="320" font-family="ui-monospace,monospace" font-size="22" fill="#7c2d12">${cl_badge} claude api: ${CL_API}</text>
  <text x="50" y="380" font-family="ui-monospace,monospace" font-size="28" font-weight="700" fill="#9a3412">score ${score} — $([ "$checks_pass" = "$checks_total" ] && echo 'ready ch-1 🚀' || echo 'see #help')</text>
  <text x="50" y="415" font-family="ui-monospace,monospace" font-size="14" fill="#a16207">vibecode.tours  ·  #ch-0  ·  ${TS}</text>
</svg>
SVG
}

render_claude_svg() {
  [ "$NO_CLAUDE" = "1" ] || [ "$CL_API" = "fail" ] && return 1
  local prompt
  prompt="Render this JSON as a single SVG badge card, 800x450, warm-amber palette (bg #fef3e2→#fde2c4, accents #d97706 #7c2d12 #9a3412), monospace text, vibecode.tours footer. Output SVG only — no markdown, no fences, no commentary. JSON:
$(cat "$JSON")"
  local out
  if out="$(claude -p "$prompt" --output-format text 2>/dev/null)" && [ -n "$out" ] && echo "$out" | grep -q "<svg"; then
    # strip any fences / pre-text
    echo "$out" | sed -n '/<svg/,/<\/svg>/p' > "$SVG"
    [ -s "$SVG" ] && return 0
  fi
  return 1
}

say "Card"; hr
if render_claude_svg; then ok "claude rendered svg: $SVG"
else render_static_svg; ok "static svg: $SVG"
fi

# ---------- 8. svg → png ----------
make_png() {
  if have rsvg-convert; then rsvg-convert "$SVG" -o "$PNG" 2>/dev/null && return 0; fi
  if have convert;       then convert "$SVG" "$PNG" 2>/dev/null && return 0; fi
  if have chromium;      then chromium --headless --no-sandbox --disable-gpu --screenshot="$PNG" --window-size=800,450 "file://$SVG" >/dev/null 2>&1 && return 0; fi
  if have google-chrome; then google-chrome --headless --no-sandbox --disable-gpu --screenshot="$PNG" --window-size=800,450 "file://$SVG" >/dev/null 2>&1 && return 0; fi
  return 1
}
if make_png; then ok "png: $PNG"
else warn "no svg→png tool (install: librsvg2-bin OR imagemagick) — posting svg as fallback"
fi

# ---------- 9. text fallback (always) ----------
{
  echo "┌─ Vibe Code Doctor ──────────────┐"
  echo "│ user:     ${GH_USER:-anonymous}"
  echo "│ platform: $PLATFORM"
  echo "│ claude:   $CLAUDE_LOC ($CHOICE)"
  echo "│ checks:   ${NODE_R}/node ${NPM_R}/npm ${PY_R}/py ${GIT_R}/git ${GH_R}/gh ${CL_R}/claude"
  echo "│ gh auth:  $GH_AUTH   pr probe: $GH_PR"
  echo "│ claude api: $CL_API"
  echo "│ score:    $checks_pass/$checks_total"
  echo "└──────────────────────────────────┘"
} > "$TXT"

# ---------- 10. final report ----------
echo
say "Drop one of these in #ch-0-intro"; hr
[ -f "$PNG" ] && echo "  image: $PNG"
[ -f "$SVG" ] && echo "  svg:   $SVG  (fallback if PNG above missing)"
echo "  text:  $TXT  (copy/paste if both above unavailable)"
echo "  json:  $JSON"
echo
echo "  After posting, wait for instructor ✅ → ch-0-done role → #ch-1 unlocks."

if [ "$CL_API" = "fail" ]; then
  echo
  say "claude API failed — recovery options:"; hr
  echo "  1. gemini  — free tier (https://gemini.google.com or 'gemini' CLI)"
  echo "  2. ollama  — offline (ollama run qwen2.5-coder:7b)"
  echo "  3. ask instructor in #help — manual /unlock after fix"
  exit 2
fi

[ "$checks_pass" = "$checks_total" ] && exit 0 || exit 2
