import { serve } from 'std/server'
import { createClient } from '@supabase/supabase-js'
import { corsHeaders } from '../_shared/cors.ts'

// Supabase 配置
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// 创建 Supabase 客户端（服务角色权限）
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 验证认证和权限
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return Response.json({ error: 'Unauthorized' }, { 
        status: 401, 
        headers: corsHeaders 
      })
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    
    if (authError || !user) {
      return Response.json({ error: 'Invalid token' }, { 
        status: 401, 
        headers: corsHeaders 
      })
    }

    // 检查是否为管理员
    const isAdmin = await checkAdminPermission(user.id)
    if (!isAdmin) {
      return Response.json({ error: 'Insufficient permissions' }, { 
        status: 403, 
        headers: corsHeaders 
      })
    }

    const url = new URL(req.url)
    const path = url.pathname.split('/').pop()

    switch (req.method) {
      case 'GET':
        return handleGet(req, path, user)
      case 'POST':
        return handlePost(req, path, user)
      case 'PUT':
        return handlePut(req, path, user)
      case 'DELETE':
        return handleDelete(req, path, user)
      default:
        return Response.json({ error: 'Method not allowed' }, { 
          status: 405, 
          headers: corsHeaders 
        })
    }
  } catch (error) {
    console.error('Forum admin error:', error)
    return Response.json({ error: 'Internal server error' }, { 
      status: 500, 
      headers: corsHeaders 
    })
  }
})

// 检查管理员权限
async function checkAdminPermission(userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('auth.users')
    .select('raw_user_meta_data')
    .eq('id', userId)
    .single()

  if (error || !data) {
    return false
  }

  return data.raw_user_meta_data?.role === 'admin'
}

// GET 请求处理
async function handleGet(req: Request, path: string | undefined, user: any) {
  const url = new URL(req.url)
  
  switch (path) {
    case 'pending-posts':
      return getPendingPosts(req)
    case 'pending-comments':
      return getPendingComments(req)
    case 'user-management':
      return getUserManagement(req)
    case 'feedback-management':
      return getFeedbackManagement(req)
    case 'forum-analytics':
      return getForumAnalytics(req)
    case 'categories':
      return getCategoriesAdmin(req)
    default:
      return Response.json({ error: 'Not found' }, { 
        status: 404, 
        headers: corsHeaders 
      })
  }
}

// POST 请求处理
async function handlePost(req: Request, path: string | undefined, user: any) {
  const body = await req.json()
  
  switch (path) {
    case 'moderate-post':
      return moderatePost(body, user)
    case 'moderate-comment':
      return moderateComment(body, user)
    case 'update-category':
      return updateCategory(body, user)
    case 'feature-post':
      return featurePost(body, user)
    case 'pin-post':
      return pinPost(body, user)
    case 'respond-feedback':
      return respondToFeedback(body, user)
    default:
      return Response.json({ error: 'Not found' }, { 
        status: 404, 
        headers: corsHeaders 
      })
  }
}

// PUT 请求处理
async function handlePut(req: Request, path: string | undefined, user: any) {
  const body = await req.json()
  
  switch (path) {
    case 'category':
      return updateCategory(body, user)
    case 'user-role':
      return updateUserRole(body, user)
    default:
      return Response.json({ error: 'Not found' }, { 
        status: 404, 
        headers: corsHeaders 
      })
  }
}

// DELETE 请求处理
async function handleDelete(req: Request, path: string | undefined, user: any) {
  const url = new URL(req.url)
  const id = url.searchParams.get('id')
  
  switch (path) {
    case 'post':
      return deletePostAdmin(parseInt(id || '0'), user)
    case 'comment':
      return deleteCommentAdmin(parseInt(id || '0'), user)
    case 'category':
      return deleteCategory(parseInt(id || '0'), user)
    default:
      return Response.json({ error: 'Not found' }, { 
        status: 404, 
        headers: corsHeaders 
      })
  }
}

// 获取待审核帖子
async function getPendingPosts(req: Request) {
  const url = new URL(req.url)
  const page = parseInt(url.searchParams.get('page') || '1')
  const limit = parseInt(url.searchParams.get('limit') || '10')
  const status = url.searchParams.get('status') || 'moderating' // moderating, rejected
  
  const offset = (page - 1) * limit
  
  const { data, error, count } = await supabase
    .from('forum_posts')
    .select(`
      *,
      author:auth.users(email, raw_user_meta_data),
      category:forum_categories(name, slug)
    `, { count: 'exact' })
    .eq('status', status)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (error) {
    throw error
  }

  return Response.json({ 
    data, 
    pagination: {
      page,
      limit,
      total: count || 0,
      totalPages: Math.ceil((count || 0) / limit)
    }
  }, { headers: corsHeaders })
}

// 获取待审核评论
async function getPendingComments(req: Request) {
  const url = new URL(req.url)
  const page = parseInt(url.searchParams.get('page') || '1')
  const limit = parseInt(url.searchParams.get('limit') || '10')
  const status = url.searchParams.get('status') || 'moderating'
  
  const offset = (page - 1) * limit
  
  const { data, error, count } = await supabase
    .from('forum_comments')
    .select(`
      *,
      user:auth.users(email),
      post:forum_posts(title, id)
    `, { count: 'exact' })
    .eq('status', status)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (error) {
    throw error
  }

  return Response.json({ 
    data, 
    pagination: {
      page,
      limit,
      total: count || 0,
      totalPages: Math.ceil((count || 0) / limit)
    }
  }, { headers: corsHeaders })
}

// 获取用户管理数据
async function getUserManagement(req: Request) {
  const url = new URL(req.url)
  const page = parseInt(url.searchParams.get('page') || '1')
  const limit = parseInt(url.searchParams.get('limit') || '10')
  const search = url.searchParams.get('search')
  
  const offset = (page - 1) * limit
  
  // 获取用户活动统计
  const query = supabase
    .rpc('get_user_forum_stats', {})
    .range(offset, offset + limit - 1)

  if (search) {
    // 这里需要在应用层进行搜索过滤，或在数据库层面创建索引视图
    console.log('Search functionality would be implemented here')
  }

  const { data, error, count } = await query as any
  
  if (error) {
    throw error
  }

  return Response.json({ 
    data, 
    pagination: {
      page,
      limit,
      total: count || 0,
      totalPages: Math.ceil((count || 0) / limit)
    }
  }, { headers: corsHeaders })
}

// 获取反馈管理数据
async function getFeedbackManagement(req: Request) {
  const url = new URL(req.url)
  const page = parseInt(url.searchParams.get('page') || '1')
  const limit = parseInt(url.searchParams.get('limit') || '10')
  const status = url.searchParams.get('status') // open, in_progress, resolved, closed
  const type = url.searchParams.get('type') // bug, feature, content, general
  
  const offset = (page - 1) * limit
  
  let query = supabase
    .from('user_feedback')
    .select(`
      *,
      user:auth.users(email, raw_user_meta_data),
      admin:auth.users(email) as admin_email
    `, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (status) {
    query = query.eq('status', status)
  }
  
  if (type) {
    query = query.eq('feedback_type', type)
  }

  const { data, error, count } = await query
  
  if (error) {
    throw error
  }

  return Response.json({ 
    data, 
    pagination: {
      page,
      limit,
      total: count || 0,
      totalPages: Math.ceil((count || 0) / limit)
    }
  }, { headers: corsHeaders })
}

// 获取论坛分析数据
async function getForumAnalytics(req: Request) {
  const url = new URL(req.url)
  const days = parseInt(url.searchParams.get('days') || '30')
  
  // 获取基本统计
  const { data: stats } = await supabase
    .from('forum_stats')
    .select('*')
    .limit(1)
    .single()

  // 获取分类统计
  const { data: categoryStats } = await supabase
    .rpc('get_category_stats', {})

  // 获取活跃用户统计
  const { data: activeUsers } = await supabase
    .from('user_activity_stats')
    .select('*')
    .limit(10)

  // 获取热门帖子
  const { data: hotPosts } = await supabase
    .from('hot_posts')
    .select('*')
    .limit(10)

  // 获取最近增长数据
  const startDate = new Date()
  startDate.setDate(startDate.getDate() - days)
  
  const { count: recentPosts } = await supabase
    .from('forum_posts')
    .select('id', { count: 'exact' })
    .gte('created_at', startDate.toISOString())
  
  const { count: recentComments } = await supabase
    .from('forum_comments')
    .select('id', { count: 'exact' })
    .gte('created_at', startDate.toISOString())

  return Response.json({
    stats,
    categoryStats,
    activeUsers,
    hotPosts,
    growthData: {
      recentPosts,
      recentComments,
      periodDays: days
    }
  }, { headers: corsHeaders })
}

// 获取分类管理数据
async function getCategoriesAdmin(req: Request) {
  const { data, error } = await supabase
    .from('forum_categories')
    .select('*')
    .order('sort_order')
    .order('name')

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 审核帖子
async function moderatePost(body: any, user: any) {
  const { post_id, action, reason } = body // action: approve, reject
  
  if (!post_id || !action) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  let newStatus = action === 'approve' ? 'published' : 'rejected'
  
  const { data, error } = await supabase
    .from('forum_posts')
    .update({
      status: newStatus,
      moderated_at: new Date().toISOString(),
      moderator_id: user.id
    })
    .eq('id', post_id)
    .select()
    .single()

  if (error) {
    throw error
  }

  if (newStatus === 'published') {
    // 设置发布时间
    await supabase
      .from('forum_posts')
      .update({ published_at: new Date().toISOString() })
      .eq('id', post_id)

    // 创建通知给用户
    const { data: post } = await supabase
      .from('forum_posts')
      .select('author_id, title')
      .eq('id', post_id)
      .single()

    if (post && post.author_id !== user.id) {
      await supabase
        .from('forum_notifications')
        .insert({
          user_id: post.author_id,
          type: 'moderation',
          title: '你的帖子已通过审核',
          content: `帖子《${post.title}》已通过审核并发布`,
          post_id,
          from_user_id: user.id
        })
    }
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 审核评论
async function moderateComment(body: any, user: any) {
  const { comment_id, action } = body
  
  if (!comment_id || !action) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const newStatus = action === 'approve' ? 'published' : 'rejected'
  
  const { data, error } = await supabase
    .from('forum_comments')
    .update({
      status: newStatus,
      moderated_at: new Date().toISOString(),
      moderator_id: user.id
    })
    .eq('id', comment_id)
    .select()
    .single()

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 更新分类
async function updateCategory(body: any, user: any) {
  const { id, name, description, slug, sort_order, is_active } = body
  
  if (!id || !name) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('forum_categories')
    .update({
      name,
      description,
      slug: slug || name.toLowerCase().replace(/\s+/g, '-'),
      sort_order: sort_order || 0,
      is_active: is_active !== undefined ? is_active : true,
      updated_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single()

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 推荐帖子
async function featurePost(body: any, user: any) {
  const { post_id, featured } = body
  
  if (!post_id) {
    return Response.json({ error: 'Missing post_id' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('forum_posts')
    .update({ is_featured: featured })
    .eq('id', post_id)
    .select()
    .single()

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 置顶帖子
async function pinPost(body: any, user: any) {
  const { post_id, pinned } = body
  
  if (!post_id) {
    return Response.json({ error: 'Missing post_id' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('forum_posts')
    .update({ is_pinned: pinned })
    .eq('id', post_id)
    .select()
    .single()

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 回复反馈
async function respondToFeedback(body: any, user: any) {
  const { feedback_id, response, status } = body
  
  if (!feedback_id || !response) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('user_feedback')
    .update({
      admin_response: response,
      status: status || 'in_progress',
      admin_id: user.id,
      updated_at: new Date().toISOString(),
      ...(status === 'resolved' && { resolved_at: new Date().toISOString() })
    })
    .eq('id', feedback_id)
    .select()
    .single()

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 更新用户角色
async function updateUserRole(body: any, user: any) {
  const { user_id, role } = body
  
  if (!user_id || !role) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { error } = await supabase
    .from('auth.users')
    .update({ 
      raw_user_meta_data: { role } 
    })
    .eq('id', user_id)

  if (error) {
    throw error
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 删除帖子（管理员）
async function deletePostAdmin(id: number, user: any) {
  const { error } = await supabase
    .from('forum_posts')
    .delete()
    .eq('id', id)

  if (error) {
    throw error
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 删除评论（管理员）
async function deleteCommentAdmin(id: number, user: any) {
  const { error } = await supabase
    .from('forum_comments')
    .delete()
    .eq('id', id)

  if (error) {
    throw error
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 删除分类
async function deleteCategory(id: number, user: any) {
  const { error } = await supabase
    .from('forum_categories')
    .delete()
    .eq('id', id)

  if (error) {
    throw error
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}