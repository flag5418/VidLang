// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/**
 * Model Config Edge Function
 * 获取本地模型下载配置
 * 
 * 返回模型文件的下载地址和版本信息
 * 支持自定义镜像地址
 */

import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 创建 Supabase 客户端
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 获取用户自定义镜像（从请求参数或请求头）
    const url = new URL(req.url)
    const customMirror = url.searchParams.get('mirror') || 
                         req.headers.get('X-Custom-Mirror')

    // 从数据库获取默认镜像
    let defaultMirror = 'https://hf-mirror.com'
    const { data: mirrors, error: mirrorError } = await supabase
      .from('model_mirror')
      .select('*')
      .eq('is_active', true)
      .order('priority', { ascending: true })
      .limit(1)

    if (!mirrorError && mirrors && mirrors.length > 0) {
      defaultMirror = mirrors[0].url
    }

    // 使用用户自定义镜像或默认镜像
    const baseUrl = customMirror || defaultMirror

    // 从数据库获取模型配置
    const { data: models, error: modelError } = await supabase
      .from('model_config')
      .select('*')
      .eq('is_active', true)
      .order('model_type', { ascending: true })

    if (modelError) {
      throw new Error(`Failed to fetch model config: ${modelError.message}`)
    }

    // 构建响应
    const response: any = {
      success: true,
      mirror: baseUrl,
      models: {},
      // 返回所有可用镜像供用户选择
      available_mirrors: mirrors || []
    }

    // 处理每个模型
    for (const model of models || []) {
      response.models[model.model_type] = {
        url: `${baseUrl}/${model.repo}/resolve/main/${model.file_path}`,
        display_name: model.display_name,
        size: model.file_size,
        size_bytes: model.file_size_bytes,
        version: model.version,
        sha256: model.sha256,
        required: model.is_required,
        repo: model.repo,
        file_path: model.file_path
      }
    }

    return new Response(JSON.stringify(response), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        // 缓存 1 小时，减少数据库查询
        'Cache-Control': 'public, max-age=3600'
      }
    })
  } catch (error) {
    console.error('Model config error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error'
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )
  }
})
