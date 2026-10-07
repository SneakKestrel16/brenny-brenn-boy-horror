import type { Register, EngineInterface } from 'claude-code'

const TOOL = 'mcp__free-delegate__delegate'

const DESCRIPTION = `Hand a simple, self-contained task to a free secondary model and get its text answer back. Saves your own tokens.

Good fits: summarising or rewording text you paste in, drafting commit messages / docstrings / comments, boilerplate and small isolated snippets, regexes, unit conversions, format conversions (JSON<->YAML, CSV), translating strings, renaming suggestions, quick factual lookups that don't need to be exact.

Bad fits: anything needing judgement about this codebase, multi-step reasoning, security-sensitive code, or anything you can't cheaply check.

The free model CANNOT see files, the conversation or tools: put everything it needs in "task" and "context". Treat its answer as a draft from a weaker model: check it before using it.`

const NUDGE = `# Delegating simple work
You have a tool, ${TOOL}, that sends a task to a free, weaker model. When a sub-task is simple, self-contained and easy to verify (summaries, rewording, boilerplate, regexes, format conversions, commit messages), prefer delegating it instead of producing it yourself, then review the result. Don't delegate anything that needs this codebase's context or careful reasoning.`

type Settings = { baseUrl: string; apiKey: string; model: string }

let calls = 0
let tokens = 0

async function settings($: EngineInterface, options: Record<string, unknown>): Promise<Settings> {
  const fromEnv =
    (await $.env.get('FREE_MODEL_API_KEY')) ?? (await $.env.get('OPENROUTER_API_KEY')) ?? ''
  return {
    baseUrl: String(options.baseUrl || 'https://openrouter.ai/api/v1').replace(/\/+$/, ''),
    apiKey: String(options.apiKey || fromEnv),
    model: String(options.model || 'meta-llama/llama-3.3-70b-instruct:free'),
  }
}

function headers(s: Settings): Record<string, string> {
  const h: Record<string, string> = { 'content-type': 'application/json' }
  if (s.apiKey) h.authorization = `Bearer ${s.apiKey}`
  if (s.baseUrl.includes('openrouter.ai')) {
    h['x-title'] = 'Claude Code free-delegate'
  }
  return h
}

export type AskResult = { ok: true; text: string; model: string; tokens: number } | { ok: false; error: string }

export async function ask(
  $: EngineInterface,
  s: Settings,
  task: string,
  context: string | undefined,
  maxTokens: number,
): Promise<AskResult> {
  const user = context ? `${task}\n\n--- context ---\n${context}` : task
  let res
  try {
    res = await $.http.fetch(`${s.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: headers(s),
      body: JSON.stringify({
        model: s.model,
        max_tokens: maxTokens,
        temperature: 0.2,
        messages: [
          {
            role: 'system',
            content:
              'You are a concise assistant doing a small task for another AI. Answer with the result only: no preamble, no sign-off. Use code fences only when returning code.',
          },
          { role: 'user', content: user },
        ],
      }),
    })
  } catch (err) {
    return { ok: false, error: `request failed: ${String(err)}` }
  }
  let body: any
  try {
    body = JSON.parse(res.text)
  } catch {
    return { ok: false, error: `HTTP ${res.status}, non-JSON reply: ${res.text.slice(0, 300)}` }
  }
  if (!res.ok || body?.error) {
    const msg = body?.error?.message ?? body?.error ?? res.text.slice(0, 300)
    return { ok: false, error: `HTTP ${res.status}: ${typeof msg === 'string' ? msg : JSON.stringify(msg)}` }
  }
  const text: unknown = body?.choices?.[0]?.message?.content
  if (typeof text !== 'string' || text.trim() === '') {
    return { ok: false, error: 'the free model returned an empty answer' }
  }
  return {
    ok: true,
    text: text.trim(),
    model: String(body.model ?? s.model),
    tokens: Number(body?.usage?.total_tokens ?? 0),
  }
}

export const register: Register = (on, options) => {
  on('session.start', async ($, e, next) => {
    await $.tool.register({
      name: 'delegate',
      description: DESCRIPTION,
      inputSchema: {
        type: 'object',
        properties: {
          task: { type: 'string', description: 'Clear, complete instructions for the free model.' },
          context: {
            type: 'string',
            description: 'Any text, code or data the task needs (the free model sees nothing else).',
          },
          max_tokens: { type: 'integer', minimum: 16, maximum: 4096, description: 'Answer length cap (default 1024).' },
        },
        required: ['task'],
      },
    })
    await $.command.register({
      name: 'delegate',
      description: 'Ask the free model something directly: /delegate <task>',
    })
    await $.command.register({
      name: 'free-models',
      description: 'List the free models your endpoint offers (OpenRouter :free models, or all models elsewhere).',
    })
    return next(e)
  })

  on('tool.call', { tool: /^mcp__free-delegate__delegate$/ }, async ($, e) => {
    const input = e as unknown as { task?: unknown; context?: unknown; max_tokens?: unknown }
    const task = typeof input.task === 'string' ? input.task : ''
    if (!task.trim()) return { deny: 'delegate needs a non-empty "task".' }
    const context = typeof input.context === 'string' && input.context ? input.context : undefined
    const maxTokens = typeof input.max_tokens === 'number' ? input.max_tokens : 1024

    const s = await settings($, options)
    $.ui.status(`free-delegate: asking ${s.model}…`)
    const r = await ask($, s, task, context, maxTokens)
    if (!r.ok) {
      $.ui.status(`free-delegate: failed (${calls} done)`)
      return { deny: `Free model unavailable (${r.error}). Do the task yourself.` }
    }
    calls += 1
    tokens += r.tokens
    $.ui.status(`free-delegate: ${calls} task${calls === 1 ? '' : 's'} offloaded · ${tokens} tokens`)
    return { result: `[answer from free model ${r.model} — verify before relying on it]\n\n${r.text}` } as any
   }).catch(($, e, next) =>
    next.called ? next(e) : { deny: 'free-delegate failed unexpectedly. Do the task yourself.' },
  )

  on('command.run', { command: 'delegate' }, async ($, e) => {
    const task = e.args.trim()
    if (!task) return { text: 'Usage: /delegate <task>' }
    const s = await settings($, options)
    const r = await ask($, s, task, undefined, 1024)
    if (!r.ok) return { text: `free-delegate: ${r.error}` }
    calls += 1
    tokens += r.tokens
    return { text: `${r.model}:\n\n${r.text}` }
  })

  on('command.run', { command: 'free-models' }, async $ => {
    const s = await settings($, options)
    let res
    try {
      res = await $.http.fetch(`${s.baseUrl}/models`, { headers: headers(s) })
    } catch (err) {
      return { text: `free-delegate: could not list models: ${String(err)}` }
    }
    if (!res.ok) return { text: `free-delegate: HTTP ${res.status} listing models` }
    let data: any[] = []
    try {
      data = JSON.parse(res.text)?.data ?? []
    } catch {
      return { text: 'free-delegate: the models list was not JSON' }
    }
    const isOpenRouter = s.baseUrl.includes('openrouter.ai')
    const ids = data
      .filter(m => !isOpenRouter || String(m.id).endsWith(':free'))
      .map(m => String(m.id))
      .sort()
    if (ids.length === 0) return { text: 'free-delegate: no free models listed.' }
    return {
      text: `Models (current: ${s.model}):\n${ids.map(id => `  ${id}`).join('\n')}\n\nSet one with /config → free-delegate.model`,
    }
  })

  if (options.nudge !== false) {
    on('prompt.compose', async ($, e, next) => {
      const r = await next(e)
      return { sections: [...r.sections, { id: 'free-delegate:nudge', text: NUDGE, scope: 'session' as const }] }
    })
  }
}
