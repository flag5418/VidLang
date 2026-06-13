// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { getUserId } from '../ai-proxy/billing.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function getSupabase() {
  return createClient(supabaseUrl, supabaseServiceKey)
}

function toDayString(date: Date): string {
  return date.toISOString().slice(0, 10)
}

function startOfDay(day?: string): Date {
  const base = day ? new Date(`${day}T00:00:00.000Z`) : new Date()
  base.setUTCHours(0, 0, 0, 0)
  return base
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date)
  next.setUTCDate(next.getUTCDate() + days)
  return next
}

function actionMeta(ruleCode: string): { key: string; label: string } {
  if (ruleCode.startsWith('ai_conversation')) {
    return { key: 'ai_conversation', label: 'AI 对话' }
  }
  if (ruleCode === 'st_pron_score') {
    return { key: 'st_pron_score', label: '跟读评分' }
  }
  if (ruleCode === 'ai_test_plan') {
    return { key: 'ai_test_plan', label: 'AI 出题' }
  }
  if (ruleCode === 'ai_definition') {
    return { key: 'ai_definition', label: 'AI 释义' }
  }
  if (ruleCode === 'ai_translate' || ruleCode === 'ai_translate_conversation') {
    return { key: 'ai_translate', label: 'AI 翻译' }
  }
  if (ruleCode === 'ai_tts') {
    return { key: 'ai_tts', label: 'AI 朗读' }
  }
  return { key: ruleCode, label: ruleCode }
}

function resourceLabel(resourceType: string): string {
  switch (resourceType) {
    case 'video':
      return '视频'
    case 'music':
      return '音频'
    case 'article':
      return '文章'
    case 'word_book':
      return '生词本'
    default:
      return '未分类'
  }
}

function normalizeResourceType(meta: Record<string, any>): string {
  const value = String(
    meta.resource_type ?? meta.source_type ?? meta.content_type ?? '',
  ).trim()
  if (value === 'subtitle') return 'video'
  if (value === 'audio') return 'music'
  if (value.length === 0) return 'unknown'
  return value
}

function normalizeEvent(row: any, ruleMap: Map<string, any>) {
  const meta = typeof row.meta === 'object' && row.meta ? row.meta : {}
  const action = meta.action_key && meta.action_label
    ? { key: String(meta.action_key), label: String(meta.action_label) }
    : actionMeta(String(row.rule_code ?? ''))
  const resourceType = normalizeResourceType(meta)
  const rule = ruleMap.get(String(row.rule_code ?? ''))
  return {
    id: row.id,
    rule_code: String(row.rule_code ?? ''),
    rule_name: String(rule?.name_zh ?? row.rule_code ?? ''),
    cost_cny: Number(row.cost_cny ?? 0),
    created_at: String(row.created_at ?? ''),
    day: String(row.created_at ?? '').slice(0, 10),
    scene: String(row.scene ?? ''),
    entry: String(row.entry ?? ''),
    action_key: action.key,
    action_label: action.label,
    resource_type: resourceType,
    resource_label: resourceLabel(resourceType),
    resource_code: String(meta.resource_code ?? meta.video_code ?? meta.source_code ?? ''),
    resource_title: String(meta.resource_title ?? meta.source_title ?? meta.title ?? ''),
    folder_code: String(meta.folder_code ?? ''),
    folder_title: String(meta.folder_title ?? ''),
    source_page: String(meta.source_page ?? row.scene ?? ''),
    action_name: String(meta.action_name ?? row.entry ?? ''),
    is_chargeable: Boolean(meta.is_chargeable ?? Number(row.cost_cny ?? 0) > 0),
  }
}

function toSortedSummary(map: Map<string, any>) {
  return Array.from(map.values()).sort((a, b) => {
    if (b.total !== a.total) return b.total - a.total
    return b.count - a.count
  })
}

async function loadRuleMap() {
  const supabase = getSupabase()
  const { data } = await supabase
    .from('pricing_rule')
    .select('rule_code, name_zh, price_cny, status')
  const map = new Map<string, any>()
  for (const item of data ?? []) {
    map.set(String(item.rule_code), item)
  }
  return map
}

async function loadEvents(userId: string, from: Date, to: Date) {
  const supabase = getSupabase()
  const { data, error } = await supabase
    .from('usage_event')
    .select('id, rule_code, scene, entry, cost_cny, meta, created_at')
    .eq('user_id', userId)
    .gte('created_at', from.toISOString())
    .lt('created_at', to.toISOString())
    .order('created_at', { ascending: false })
  if (error) throw error
  return data ?? []
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return json({ ok: false, error: 'method_not_allowed' }, 405)
  }

  try {
    const userId = await getUserId(req)
    if (!userId) {
      return json({ ok: false, error: 'unauthorized' }, 401)
    }

    const body = (await req.json().catch(() => ({}))) as any
    const op = String(body.op ?? 'overview')
    const day = String(body.day ?? toDayString(new Date()))
    const trendDays = Math.max(3, Math.min(30, Number(body.trend_days ?? 7)))

    const dayStart = startOfDay(day)
    const dayEnd = addDays(dayStart, 1)
    const trendStart = addDays(dayStart, -(trendDays - 1))
    const ruleMap = await loadRuleMap()

    if (op === 'overview') {
      const events = (await loadEvents(userId, trendStart, dayEnd)).map((e) =>
        normalizeEvent(e, ruleMap)
      )
      const todayEvents = events.filter((e) => e.day === day)

      const actionMap = new Map<string, any>()
      for (const e of todayEvents) {
        const key = e.action_key
        const current = actionMap.get(key) ?? {
          key,
          label: e.action_label,
          count: 0,
          total: 0,
        }
        current.count += 1
        current.total += e.cost_cny
        actionMap.set(key, current)
      }

      const resourceMap = new Map<string, any>()
      for (const e of todayEvents) {
        const key = e.resource_type
        const current = resourceMap.get(key) ?? {
          key,
          label: e.resource_label,
          count: 0,
          total: 0,
        }
        current.count += 1
        current.total += e.cost_cny
        resourceMap.set(key, current)
      }

      const trendMap = new Map<string, number>()
      for (let i = 0; i < trendDays; i++) {
        trendMap.set(toDayString(addDays(trendStart, i)), 0)
      }
      for (const e of events) {
        trendMap.set(e.day, (trendMap.get(e.day) ?? 0) + e.cost_cny)
      }

      const rules = Array.from(ruleMap.values())
        .sort((a, b) => Number(b.price_cny ?? 0) - Number(a.price_cny ?? 0))
        .map((item) => ({
          rule_code: String(item.rule_code ?? ''),
          name_zh: String(item.name_zh ?? item.rule_code ?? ''),
          price_cny: Number(item.price_cny ?? 0),
          status: String(item.status ?? 'active'),
          is_chargeable: Number(item.price_cny ?? 0) > 0,
        }))

      return json({
        ok: true,
        day,
        day_total: todayEvents.reduce((sum, e) => sum + e.cost_cny, 0),
        trend: Array.from(trendMap.entries()).map(([date, total]) => ({
          date,
          total,
        })),
        action_summary: toSortedSummary(actionMap),
        resource_summary: toSortedSummary(resourceMap),
        pricing_rules: rules,
      })
    }

    if (op === 'action_details') {
      const actionKey = String(body.action_key ?? '').trim()
      if (!actionKey) {
        return json({ ok: false, error: 'missing_action_key' }, 400)
      }
      const events = (await loadEvents(userId, dayStart, dayEnd))
        .map((e) => normalizeEvent(e, ruleMap))
        .filter((e) => e.action_key === actionKey)
      const total = events.reduce((sum, e) => sum + e.cost_cny, 0)
      return json({
        ok: true,
        day,
        action: {
          key: actionKey,
          label: events[0]?.action_label ?? actionMeta(actionKey).label,
          total,
          count: events.length,
        },
        details: events,
      })
    }

    if (op === 'resource_type_details') {
      const resourceType = String(body.resource_type ?? '').trim()
      const search = String(body.search ?? '').trim().toLowerCase()
      if (!resourceType) {
        return json({ ok: false, error: 'missing_resource_type' }, 400)
      }
      let events = (await loadEvents(userId, dayStart, dayEnd))
        .map((e) => normalizeEvent(e, ruleMap))
        .filter((e) => e.resource_type === resourceType)
      if (search.length > 0) {
        events = events.filter((e) =>
          e.resource_title.toLowerCase().includes(search) ||
          e.folder_title.toLowerCase().includes(search)
        )
      }

      const folderMap = new Map<string, any>()
      const resourceMap = new Map<string, any>()
      for (const e of events) {
        const folderKey = e.folder_code || `__folder__${e.folder_title || '未归档'}`
        const folderCurrent = folderMap.get(folderKey) ?? {
          folder_code: e.folder_code,
          folder_title: e.folder_title || '未归档',
          total: 0,
          count: 0,
        }
        folderCurrent.total += e.cost_cny
        folderCurrent.count += 1
        folderMap.set(folderKey, folderCurrent)

        const resourceKey = e.resource_code || `__resource__${e.resource_title || e.id}`
        const resourceCurrent = resourceMap.get(resourceKey) ?? {
          resource_code: e.resource_code,
          resource_title: e.resource_title || '未命名资源',
          folder_code: e.folder_code,
          folder_title: e.folder_title || '未归档',
          total: 0,
          count: 0,
        }
        resourceCurrent.total += e.cost_cny
        resourceCurrent.count += 1
        resourceMap.set(resourceKey, resourceCurrent)
      }

      return json({
        ok: true,
        day,
        resource_type: resourceType,
        resource_label: resourceLabel(resourceType),
        summary: {
          total: events.reduce((sum, e) => sum + e.cost_cny, 0),
          count: events.length,
        },
        folders: toSortedSummary(folderMap),
        resources: toSortedSummary(resourceMap),
      })
    }

    if (op === 'resource_details') {
      const resourceType = String(body.resource_type ?? '').trim()
      const resourceCode = String(body.resource_code ?? '').trim()
      if (!resourceType || !resourceCode) {
        return json({ ok: false, error: 'missing_resource_filters' }, 400)
      }
      const events = (await loadEvents(userId, dayStart, dayEnd))
        .map((e) => normalizeEvent(e, ruleMap))
        .filter(
          (e) =>
            e.resource_type === resourceType && e.resource_code === resourceCode,
        )
      return json({
        ok: true,
        day,
        resource: {
          resource_type: resourceType,
          resource_label: resourceLabel(resourceType),
          resource_code: resourceCode,
          resource_title: events[0]?.resource_title ?? '未命名资源',
          folder_code: events[0]?.folder_code ?? '',
          folder_title: events[0]?.folder_title ?? '',
          total: events.reduce((sum, e) => sum + e.cost_cny, 0),
          count: events.length,
        },
        details: events,
      })
    }

    return json({ ok: false, error: 'unsupported_op' }, 400)
  } catch (e: any) {
    return json(
      { ok: false, error: 'internal_error', message: e.message || String(e) },
      500,
    )
  }
})
