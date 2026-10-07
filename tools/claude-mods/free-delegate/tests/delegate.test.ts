import { test, expect, mock } from 'claude-code/testing'

const TOOL = 'mcp__free-delegate__delegate'

test('delegate sends the task to the free model and returns its answer', { options: { apiKey: 'k', model: 'x/y:free' } }, async ($, on) => {
  mock.env(on, {})
  let sent: any
  on('http.fetch', async ($, e) => {
    sent = e
    return { value: {
      status: 200,
      ok: true,
      headers: {},
      text: JSON.stringify({ model: 'x/y:free', choices: [{ message: { content: ' feat: add thing ' } }], usage: { total_tokens: 42 } }),
    } }
  })
  const r: any = await $.tool.call({ tool: TOOL, task: 'write a commit message', context: 'diff here' } as any)
  expect(String(sent.url)).toBe('https://openrouter.ai/api/v1/chat/completions')
  expect(sent.init.headers.authorization).toBe('Bearer k')
  const body = JSON.parse(sent.init.body)
  expect(body.model).toBe('x/y:free')
  expect(body.messages[1].content).toContain('diff here')
  expect(JSON.stringify(r)).toContain('feat: add thing')
})

test('delegate refuses with a fallback note when the endpoint errors', async ($, on) => {
  mock.env(on, {})
  on('http.fetch', async () => ({ value: { status: 429, ok: false, headers: {}, text: '{"error":{"message":"rate limited"}}' } }))
  const r: any = await $.tool.call({ tool: TOOL, task: 'hi' } as any)
  expect(JSON.stringify(r)).toContain('rate limited')
  expect(JSON.stringify(r)).toContain('Do the task yourself')
})
