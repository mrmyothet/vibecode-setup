# API Pricing & Free-Tier Cheat Sheet

Quick reference for picking a provider/CLI on day 1. **All numbers verified early-mid 2026 — confirm live before you depend on them.** Pricing and quotas change frequently (especially Chinese providers and free-tier limits).

## TL;DR — what to use day 1

| Goal | Pick | Why |
|------|------|-----|
| **Zero cost, zero card** | **Gemini CLI** with personal Google account | Generous free tier, no card required, 60 req/min |
| Zero cost + multi-provider | **opencode** + Gemini API key (AI Studio free tier) | Model-agnostic CLI; swap providers later without changing tool |
| Best quality, paid | Claude Code with Anthropic API or Bedrock | Top coding quality; budget $5–10/student/month is realistic |
| Cheapest paid bulk | DeepSeek V4 Flash via opencode | $0.14/$0.28 per M tokens — 20× cheaper than Claude |

If your region blocks `claude.ai`, **skip Claude Code on day 1** — use Gemini CLI or opencode instead. We'll add the regional fallback later.

---

## Free tiers — no card, no commit

### Gemini CLI (personal Google account login)

- **Provider:** Google Gemini Code Assist (consumer tier).
- **Auth:** browser sign-in with a personal Google account on first run.
- **Quota:** up to **60 requests/minute**, **~1,000 requests/day** on Flash; cap drops to ~100/day on Pro-class models.
- **Cost:** **$0**. No card. May log prompts for training (read the consent screen).
- **Install:** `npm i -g @google/gemini-cli` → `gemini`.

### Google AI Studio API key (free tier)

- **Provider:** `ai.google.dev` — separate from Gemini CLI; gives you an API key you can wire into opencode/LiteLLM/anything.
- **Free quotas** (per-day, per-model, no card):
  - **Gemini 2.5 Pro** — ~100 requests/day · 5 req/min
  - **Gemini 2.5 Flash** — ~250 requests/day · 10 req/min
  - **Gemini 2.5 Flash-Lite** — ~1,500 requests/day · 15 req/min
- **Cost:** **$0** within the quota; over-quota = 429 until reset.
- **Get a key:** https://aistudio.google.com/app/apikey

### OpenRouter (BYOK + `:free` models)

- **Free BYOK:** **1,000,000 requests/month** routed through OpenRouter to your own provider keys, then 5% surcharge.
- **`:free` models:** real free hosted variants (Qwen3-Coder, DeepSeek, GLM, Kimi) rate-limited to **1,000 req/day after a one-time $10 top-up**; **50/day without**.
- **Catch:** free traffic may be logged/used for upstream training.
- **Get a key:** https://openrouter.ai/

---

## Paid APIs — $/M tokens (early-mid 2026)

Numbers below are list pricing per 1,000,000 tokens, input then output. **Cached input read** = the price for repeated context (huge cost saver for coding agents that resend the same files).

| Provider / Model | Input | Cached read | Output |
|---|---|---|---|
| **Anthropic Claude Sonnet 4.5** | $3.00 | $0.30 | $15.00 |
| **Anthropic Claude Haiku 4.5** | $1.00 | $0.10 | $5.00 |
| **OpenAI gpt-5-codex** | $1.25 | $0.125 | $10.00 |
| **Google Gemini 2.5 Pro** | $1.25 (≤200k ctx) | $0.31 | $10.00 |
| **Google Gemini 2.5 Flash** | $0.30 | $0.075 | $2.50 |
| **Google Gemini 2.5 Flash-Lite** | $0.10 | low | $0.40 |
| **Z.ai GLM-4.6** | $0.39 | low | $1.74 |
| **MiniMax M2** | $0.255 | none | $1.00 |
| **Alibaba Qwen3-Coder** | $0.22 | none | $0.90 |
| **DeepSeek V4 Flash** | $0.14 | $0.0028 | $0.28 |
| **DeepSeek V4 Pro (list)** | $1.74 | $0.0145 | $3.48 |
| **DeepSeek V4 Pro (promo to 2026-05-31)** | $0.435 | $0.0036 | $0.87 |

**Sources to verify:**
- Anthropic: https://www.anthropic.com/api  (or `platform.claude.com/docs/en/about-claude/pricing`)
- OpenAI: https://developers.openai.com/codex/pricing
- Gemini: https://ai.google.dev/gemini-api/docs/pricing
- DeepSeek: https://api-docs.deepseek.com/quick_start/pricing
- MiniMax: https://platform.minimax.io/docs/pricing/overview
- Z.ai / GLM: https://docs.z.ai/guides/overview/pricing
- OpenRouter: https://openrouter.ai/

---

## Flat-rate subscriptions (predictable per-user cost)

| Plan | $/month | What you get | Works with |
|---|---|---|---|
| **Claude Pro** | $20 | 5h session cap + weekly cap (~40–80 Sonnet hrs/week) | Claude Code (native) |
| **Claude Max 5x / 20x** | $100 / $200 | 5× / 20× Pro | Claude Code (native) |
| **ChatGPT Go / Plus / Pro** | $8 / $20 / $100 | message-based (15–80 msgs / 5h on Plus) | Codex CLI |
| **GitHub Copilot Free / Pro / Pro+** | $0 / $10 / $39 | usage credits (moving to credits Jun 2026) | Copilot agent |
| **Cursor Pro** | $20 | ~$20 credit pool (~225 Sonnet req/mo) | Cursor IDE |
| **Z.ai GLM Coding Plan Lite / Pro** | $10 / $30 | ~120 prompts/5h (Lite); GLM-5.x models | Claude Code, opencode, Cursor |
| **MiniMax Coding Starter** | $10 | ~100 prompts / 5h on M2.1 | Any |
| **opencode Go** | $10 ($5 first month) | $60/mo usage value across 13 open models | opencode (native) |
| **opencode Zen** | pay-as-you-go | per-token gateway, mostly $0.30–$3.20/M | opencode (native) |

**Important:** quota caps on flat subs are usually measured in *prompts* (not tokens). If you blow through "120 prompts / 5h" with one heavy session you wait 5h — not great for an active coding day. For predictable cost on a budget, token-metered APIs through one gateway usually win.

---

## What $1 buys you (rough)

Per-prompt is tiny; per-day is what matters. Coding-agent turn averages **~5,000 input + 500 output tokens** (lots more if you load a big file). With **60% cache-hit** (typical for repeat-edit sessions):

| Provider / Model | Tokens per $1 (light coding) | Approx prompts |
|---|---|---|
| Claude Sonnet 4.5 | ~250k mixed | ~40 prompts |
| OpenAI gpt-5-codex | ~330k mixed | ~55 prompts |
| Claude Haiku 4.5 | ~800k mixed | ~130 prompts |
| Gemini 2.5 Flash | ~1.5M mixed | ~250 prompts |
| Z.ai GLM-4.6 | ~1.8M mixed | ~300 prompts |
| MiniMax M2 / Qwen3-Coder | ~3.5M mixed | ~580 prompts |
| Gemini Flash-Lite | ~7M mixed | ~1,200 prompts |
| DeepSeek V4 Flash | ~8M mixed | ~1,400 prompts |

*(Indicative only — real cost depends on your prompt size + cache hit rate.)*

---

## How tokens work — the 30-second version

- **Token ≈ 4 characters** in English; Burmese script ≈ 1 character per token (worse ratio — same text uses more tokens in Burmese).
- **Input tokens** = your message + the model's context (files, system prompt, history).
- **Output tokens** = what the model writes back.
- **Cache read** (Claude/OpenAI/Gemini) = repeated input cached at ~10% price. Huge saver in coding agents that re-send the same files.
- **A "long context"** model (1M tokens) means you can paste a large codebase; you still pay per token.
- **Tip:** prefer agents that **stream + truncate** old turns instead of re-sending everything.

---

## Picking a provider for the bootcamp

1. **Day 1, no card available:** **Gemini CLI** (personal account) → free, instant.
2. **Day 1, with a card / Google account, want flexibility:** **opencode + AI Studio API key** → free Flash-Lite tier, scale to paid later.
3. **Premium quality, ok with spend:** **Claude Code** via Anthropic API or AWS Bedrock. Budget $5–10/student/mo, more for heavy use.
4. **Cheapest paid bulk:** **DeepSeek V4 Flash** (~$0.14/$0.28 per M tokens) via opencode.
5. **Predictable flat:** **Z.ai GLM Coding Plan Lite** ($10/mo, works in Claude Code) or **opencode Go** ($10/mo bundle).

The bootcamp will publish a shared proxy when it's deployed + secured — at that point students will get a single virtual key that routes to whatever model the proxy is configured for. Until then, pick from the list above.

---

## Caveats

- **Prices verified early-mid 2026.** Confirm on each provider's official pricing page before quoting externally.
- **Free-tier limits change.** Google dropped 2.5 Pro free tier in April 2026; Flash dropped to ~250/day. OpenRouter's `:free` rate-limit can change without notice.
- **Cache assumptions matter.** A 60% cache-hit rate is realistic for coding agents that revisit the same files; one-shot questions get ~0% cache and cost more.
- **Quotas in prompts vs tokens are different things.** Flat subs cap prompts; APIs cap tokens. A "120 prompts/5h" plan is not equivalent to "X tokens/5h" — measure your usage profile before committing.
- **Burmese costs ~2× more in tokens than English** for the same meaning. Plan for it on bilingual projects.

If you find a current price that disagrees with this table, **the live provider page wins** — open a PR to fix this doc.
