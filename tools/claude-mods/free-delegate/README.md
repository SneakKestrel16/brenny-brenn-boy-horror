# free-delegate (Claude Code mod)

Lets Claude hand simple, self-contained jobs (summaries, rewording, commit messages,
boilerplate, regexes, format conversions) to a **free model** on any OpenAI-compatible
endpoint, so they don't use your Claude tokens.

What it adds:
- a tool Claude can call, `mcp__free-delegate__delegate` (Claude passes along everything the free model needs, then checks the answer)
- `/delegate <task>`: ask the free model something yourself
- `/free-models`: list the free models your endpoint offers
- a status-line counter of offloaded tasks and tokens
- a short system-prompt note telling Claude when to delegate (switch off with the `nudge` option)

## Install

```
/plugin install free-delegate --marketplace sneakkestrel16/brenny-brenn-boy-horror
```

Answer `y` to add the marketplace, then choose a scope. Or run it from a checkout:
`claude --plugin-dir tools/claude-mods/free-delegate`.

## Setup

Defaults to OpenRouter's free models. Get a free key at https://openrouter.ai/keys and
either enter it in `/config` → free-delegate → API key, or export `OPENROUTER_API_KEY`
(or `FREE_MODEL_API_KEY`).

Other free options (set `baseUrl` + `model` in `/config`):

| Provider | baseUrl | key |
| --- | --- | --- |
| OpenRouter (`:free` models) | `https://openrouter.ai/api/v1` | free key |
| Groq | `https://api.groq.com/openai/v1` | free key |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | free key |
| Ollama (local) | `http://localhost:11434/v1` | none |

Free model lineups change often. If the default model stops working, run `/free-models`
and pick another one. If the free model fails (rate limit, outage), Claude is told to
do the task itself.

## Development

`claude plugin validate tools/claude-mods/free-delegate` and
`claude plugin test tools/claude-mods/free-delegate`.
