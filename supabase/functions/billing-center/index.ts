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

function startOfWeek(day?: string): Date {
  const base = startOfDay(day)
  const dayOfWeek = base.getUTCDay()
  base.setUTCDate(base.getUTCDate() - dayOfWeek)
  return base
}

function startOfMonth(day?: string): Date {
  const base = startOfDay(day)
  base.setUTCDate(1)
  return base
}

function startOfThreeMonths(day?: string): Date {
  const base = startOfDay(day)
  base.setUTCDate(base.getUTCDate() - 90)
  return base
}

function actionMeta(ruleCode: string): { key: string; label: string; category: string } {
  if (ruleCode.startsWith('ai_conversation')) {
    return { key: 'ai_conversation', label: 'AI 对话', category: 'conversation' }
  }
  if (ruleCode === 'st_pron_score') {
    return { key: 'st_pron_score', label: '跟读评分', category: 'evaluate' }
  }
  if (ruleCode === 'ai_test_plan') {
    return { key: 'ai_test_plan', label: 'AI 出题', category: 'evaluate' }
  }
  if (ruleCode === 'ai_definition') {
    return { key: 'ai_definition', label: 'AI 释义', category: 'lookup' }
  }
  if (ruleCode === 'ai_word_link') {
    return { key: 'ai_word_link', label: 'AI 词联', category: 'lookup' }
  }
  if (ruleCode === 'ai_translate' || ruleCode === 'ai_translate_conversation') {
    return { key: 'ai_translate', label: 'AI 翻译', category: 'translate' }
  }
  if (ruleCode === 'ai_tts') {
    return { key: 'ai_tts', label: 'AI 朗读', category: 'tts' }
  }
  if (ruleCode === 'ai_evaluate') {
    return { key: 'ai_evaluate', label: 'AI 评测', category: 'evaluate' }
  }
  return { key: ruleCode, label: ruleCode, category: 'other' }
}

function categoryLabel(category: string): string {
  switch (category) {
    case 'translate': return '翻译'
    case 'tts': return 'AI 发音'
    case 'conversation': return 'AI 对话'
    case 'lookup': return '智能查词'
    case 'evaluate': return '评测与测试'
    default: return '其他'
  }
}

function resourceLabel(resourceType: string): string {
  switch (resourceType) {
    case 'video': return '视频'
    case 'music': return '音频'
    case 'article': return '文章'
    case 'word_book': return '生词本'
    case 'test': return '测试'
    default: return '未分类'
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
  const metaAction = meta.action_key && meta.action_label
    ? { key: String(meta.action_key), label: String(meta.action_label) }
    : actionMeta(String(row.rule_code ?? ''))
  const category = actionMeta(String(row.rule_code ?? '')).category
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
    action_key: metaAction.key,
    action_label: metaAction.label,
    category,
    category_label: categoryLabel(category),
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

function parseTimeRange(body: any, defaultDay?: string): { from: Date; to: Date; label: string } {
  const mode = String(body.time_mode ?? 'day')
  const day = String(body.day ?? defaultDay ?? toDayString(new Date()))
  
  switch (mode) {
    case 'week':
      return { from: startOfWeek(day), to: addDays(startOfDay(day), 1), label: '本周' }
    case 'month':
      return { from: startOfMonth(day), to: addDays(startOfDay(day), 1), label: '本月' }
    case 'three_months':
      return { from: startOfThreeMonths(day), to: addDays(startOfDay(day), 1), label: '近三月' }
    case 'custom': {
      const fromStr = String(body.from ?? '').slice(0, 10)
      const toStr = String(body.to ?? '').slice(0, 10)
      const from = fromStr ? startOfDay(fromStr) : startOfDay(day)
      const to = toStr ? addDays(startOfDay(toStr), 1) : addDays(startOfDay(day), 1)
      return { from, to, label: `${fromStr || day} ~ ${toStr || day}` }
    }
    case 'day':
    default:
      return { from: startOfDay(day), to: addDays(startOfDay(day), 1), label: day }
  }
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
    const timeRange = parseTimeRange(body)
    const trendDays = Math.max(3, Math.min(30, Number(body.trend_days ?? 7)))

    const ruleMap = await loadRuleMap()

    if (op === 'overview') {
      const events = (await loadEvents(userId, timeRange.from, timeRange.to)).map((e) =>
        normalizeEvent(e, ruleMap)
      )

      const actionMap = new Map<string, any>()
      for (const e of events) {
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
      for (const e of events) {
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

      // 计算趋势（按时间范围的起始日期开始）
      const trendMap = new Map<string, number>()
      const dayCount = Math.ceil((timeRange.to.getTime() - timeRange.from.getTime()) / (24 * 60 * 60 * 1000))
      for (let i = 0; i < Math.min(dayCount, trendDays); i++) {
        trendMap.set(toDayString(addDays(timeRange.from, i)), 0)
      }
      for (const e of events) {
        const dayStr = e.day
        if (trendMap.has(dayStr)) {
          trendMap.set(dayStr, (trendMap.get(dayStr) ?? 0) + e.cost_cny)
        }
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
        time_label: timeRange.label,
        total_cost: events.reduce((sum, e) => sum + e.cost_cny, 0),
        total_count: events.length,
        trend: Array.from(trendMap.entries()).map(([date, total]) => ({
          date,
          total,
        })),
        action_summary: toSortedSummary(actionMap),
        resource_summary: toSortedSummary(resourceMap),
        pricing_rules: rules,
      })
    }

    if (op === 'by_category') {
      const events = (await loadEvents(userId, timeRange.from, timeRange.to)).map((e) =>
        normalizeEvent(e, ruleMap)
      )

      const categoryMap = new Map<string, any>()
      for (const e of events) {
        const key = e.category
        const current = categoryMap.get(key) ?? {
          category: key,
          name_zh: categoryLabel(key),
          total_cost_cny: 0,
          total_count: 0,
          by_rule: new Map<string, any>(),
          by_source: new Map<string, any>(),
        }
        current.total_cost_cny += e.cost_cny
        current.total_count += 1

        // 按规则聚合
        const ruleKey = e.rule_code
        const ruleCurrent = current.by_rule.get(ruleKey) ?? {
          rule_code: e.rule_code,
          name_zh: e.rule_name,
          cost_cny: 0,
          count: 0,
        }
        ruleCurrent.cost_cny += e.cost_cny
        ruleCurrent.count += 1
        current.by_rule.set(ruleKey, ruleCurrent)

        // 按资源聚合
        if (e.resource_code) {
          const sourceKey = `${e.resource_type}:${e.resource_code}`
          const sourceCurrent = current.by_source.get(sourceKey) ?? {
            source_type: e.resource_type,
            source_code: e.resource_code,
            source_title: e.resource_title,
            cost_cny: 0,
            count: 0,
          }
          sourceCurrent.cost_cny += e.cost_cny
          sourceCurrent.count += 1
          current.by_source.set(sourceKey, sourceCurrent)
        }

        categoryMap.set(key, current)
      }

      // 转换 Map 为 Array
      const categories = Array.from(categoryMap.values()).map(c => ({
        ...c,
        by_rule: Array.from(c.by_rule.values()).sort((a: any, b: any) => b.cost_cny - a.cost_cny),
        by_source: Array.from(c.by_source.values()).sort((a: any, b: any) => b.cost_cny - a.cost_cny),
      })).sort((a, b) => b.total_cost_cny - a.total_cost_cny)

      return json({
        ok: true,
        time_label: timeRange.label,
        total_cost: events.reduce((sum, e) => sum + e.cost_cny, 0),
        total_count: events.length,
        categories,
      })
    }

    if (op === 'category_detail') {
      const category = String(body.category ?? '').trim()
      if (!category) {
        return json({ ok: false, error: 'missing_category' }, 400)
      }

      const events = (await loadEvents(userId, timeRange.from, timeRange.to))
        .map((e) => normalizeEvent(e, ruleMap))
        .filter((e) => e.category === category)

      const ruleMap2 = new Map<string, any>()
      for (const e of events) {
        const key = e.rule_code
        const current = ruleMap2.get(key) ?? {
          rule_code: e.rule_code,
          name_zh: e.rule_name,
          cost_cny: 0,
          count: 0,
        }
        current.cost_cny += e.cost_cny
        current.count += 1
        ruleMap2.set(key, current)
      }

      // 按资源聚合
      const sourceMap = new Map<string, any>()
      for (const e of events) {
        if (e.resource_code) {
          const key = `${e.resource_type}:${e.resource_code}`
          const current = sourceMap.get(key) ?? {
            source_type: e.resource_type,
            source_code: e.resource_code,
            source_title: e.resource_title,
            cost_cny: 0,
            count: 0,
          }
          current.cost_cny += e.cost_cny
          current.count += 1
          sourceMap.set(key, current)
        }
      }

      // 按日聚合
      const dailyMap = new Map<string, { date: string; cost_cny: number; count: number }>()
      for (const e of events) {
        const day = e.day
        const current = dailyMap.get(day) ?? { date: day, cost_cny: 0, count: 0 }
        current.cost_cny += e.cost_cny
        current.count += 1
        dailyMap.set(day, current)
      }

      return json({
        ok: true,
        time_label: timeRange.label,
        category,
        name_zh: categoryLabel(category),
        total_cost_cny: events.reduce((sum, e) => sum + e.cost_cny, 0),
        total_count: events.length,
        by_rule: Array.from(ruleMap2.values()).sort((a, b) => b.cost_cny - a.cost_cny),
        by_source: Array.from(sourceMap.values()).sort((a, b) => b.cost_cny - a.cost_cny),
        daily: Array.from(dailyMap.values()).sort((a, b) => a.date.localeCompare(b.date)),
      })
    }

    if (op === 'by_source') {
      const events = (await loadEvents(userId, timeRange.from, timeRange.to)).map((e) =>
        normalizeEvent(e, ruleMap)
      )

      const sourceTypeMap = new Map<string, any>()
      let unknownCost = 0

      for (const e of events) {
        if (!e.resource_code) {
          unknownCost += e.cost_cny
          continue
        }

        const sourceTypeKey = e.resource_type
        let sourceTypeGroup = sourceTypeMap.get(sourceTypeKey)
        if (!sourceTypeGroup) {
          sourceTypeGroup = {
            source_type: sourceTypeKey,
            source_type_zh: resourceLabel(sourceTypeKey),
            items: new Map<string, any>(),
            subtotal_cny: 0,
          }
          sourceTypeMap.set(sourceTypeKey, sourceTypeGroup)
        }

        const sourceKey = e.resource_code
        const current = sourceTypeGroup.items.get(sourceKey) ?? {
          source_code: e.resource_code,
          source_title: e.resource_title || '未命名资源',
          cost_cny: 0,
          count: 0,
        }
        current.cost_cny += e.cost_cny
        current.count += 1
        sourceTypeGroup.items.set(sourceKey, current)
        sourceTypeGroup.subtotal_cny += e.cost_cny
      }

      // 转换 Map 为 Array
      const sources = Array.from(sourceTypeMap.values()).map(s => ({
        ...s,
        items: Array.from(s.items.values()).sort((a: any, b: any) => b.cost_cny - a.cost_cny),
      })).sort((a, b) => b.subtotal_cny - a.subtotal_cny)

      return json({
        ok: true,
        time_label: timeRange.label,
        total_cost: events.reduce((sum, e) => sum + e.cost_cny, 0),
        total_count: events.length,
        sources,
        unknown_source_cost_cny: unknownCost,
      })
    }

    if (op === 'source_detail') {
      const sourceType = String(body.source_type ?? '').trim()
      const sourceCode = String(body.source_code ?? '').trim()
      if (!sourceType || !sourceCode) {
        return json({ ok: false, error: 'missing_source_filters' }, 400)
      }

      const events = (await loadEvents(userId, timeRange.from, timeRange.to))
        .map((e) => normalizeEvent(e, ruleMap))
        .filter((e) => e.resource_type === sourceType && e.resource_code === sourceCode)

      // 按功能分类聚合
      const categoryMap = new Map<string, any>()
      for (const e of events) {
        const key = e.category
        const current = categoryMap.get(key) ?? {
          category: key,
          name_zh: categoryLabel(key),
          cost_cny: 0,
          count: 0,
        }
        current.cost_cny += e.cost_cny
        current.count += 1
        categoryMap.set(key, current)
      }

      // 按日聚合
      const dailyMap = new Map<string, { date: string; cost_cny: number; count: number }>()
      for (const e of events) {
        const day = e.day
        const current = dailyMap.get(day) ?? { date: day, cost_cny: 0, count: 0 }
        current.cost_cny += e.cost_cny
        current.count += 1
        dailyMap.set(day, current)
      }

      return json({
        ok: true,
        time_label: timeRange.label,
        source_type: sourceType,
        source_code: sourceCode,
        source_title: events[0]?.resource_title || '未命名资源',
        total_cost_cny: events.reduce((sum, e) => sum + e.cost_cny, 0),
        total_count: events.length,
        by_category: Array.from(categoryMap.values()).sort((a, b) => b.cost_cny - a.cost_cny),
        daily: Array.from(dailyMap.values()).sort((a, b) => a.date.localeCompare(b.date)),
      })
    }

    if (op === 'action_details') {
      const actionKey = String(body.action_key ?? '').trim()
      if (!actionKey) {
        return json({ ok: false, error: 'missing_action_key' }, 400)
      }
      const events = (await loadEvents(userId, timeRange.from, timeRange.to))
        .map((e) => normalizeEvent(e, ruleMap))
        .filter((e) => e.action_key === actionKey)
      const total = events.reduce((sum, e) => sum + e.cost_cny, 0)
      return json({
        ok: true,
        time_label: timeRange.label,
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
      let events = (await loadEvents(userId, timeRange.from, timeRange.to))
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
        time_label: timeRange.label,
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
      const events = (await loadEvents(userId, timeRange.from, timeRange.to))
        .map((e) => normalizeEvent(e, ruleMap))
        .filter(
          (e) =>
            e.resource_type === resourceType && e.resource_code === resourceCode,
        )
      return json({
        ok: true,
        time_label: timeRange.label,
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
