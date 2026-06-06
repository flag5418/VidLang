// deno-lint-ignore-file no-explicit-any
import { serve } from 'std/http/server'

serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'method_not_allowed' }), {
        status: 405,
        headers: { 'content-type': 'application/json' },
      })
    }

    const body = (await req.json().catch(() => ({}))) as any
    return new Response(JSON.stringify({ ok: true, echo: body }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'content-type': 'application/json' },
    })
  }
})
