import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
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
    // 验证认证
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
    console.error('Forum service error:', error)
    return Response.json({ error: 'Internal server error' }, { 
      status: 500, 
      headers: corsHeaders 
    })
  }
})

// GET 请求处理
async function handleGet(req: Request, path: string | undefined, user: any) {
  const url = new URL(req.url)
  
  switch (path) {
    case 'posts':
      return getPosts(req)
    case 'categories':
      return getCategories()
    case 'user-posts':
      return getUserPosts(user.id, req)
    case 'favorites':
      return getUserFavorites(user.id)
    case 'notifications':
      return getUserNotifications(user.id, req)
    case 'stats':
      return getForumStats()
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
    case 'posts':
      return createPost(body, user)
    case 'comments':
      return createComment(body, user)
    case 'like-post':
      return likePost(body, user)
    case 'like-comment':
      return likeComment(body, user)
    case 'favorite':
      return addFavorite(body, user)
    case 'feedback':
      return submitFeedback(body, user)
    case 'notifications-read':
      return markNotificationsRead(body, user)
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
    case 'post':
      return updatePost(body, user)
    case 'comment':
      return updateComment(body, user)
    case 'user-preferences':
      return updateUserPreferences(body, user)
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
      return deletePost(parseInt(id || '0'), user)
    case 'comment':
      return deleteComment(parseInt(id || '0'), user)
    case 'like-post':
      return unlikePost(parseInt(id || '0'), user)
    case 'favorite':
      return removeFavorite(parseInt(id || '0'), user)
    default:
      return Response.json({ error: 'Not found' }, { 
        status: 404, 
        headers: corsHeaders 
      })
  }
}

// 获取帖子列表
async function getPosts(req: Request) {
  const url = new URL(req.url)
  const page = parseInt(url.searchParams.get('page') || '1')
  const limit = parseInt(url.searchParams.get('limit') || '10')
  const category = url.searchParams.get('category')
  const type = url.searchParams.get('type')
  const search = url.searchParams.get('search')
  
  const offset = (page - 1) * limit
  
  let query = supabase
    .from('forum_posts')
    .select(`
      *,
      author:auth.users(email, raw_user_meta_data),
      category:forum_categories(name, slug),
      like_count,
      comment_count,
      view_count
    `, { count: 'exact' })
    .eq('status', 'published')
    .order('is_pinned', { ascending: false })
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (category) {
    query = query.eq('category_id', category)
  }
  
  if (type) {
    query = query.eq('post_type', type)
  }
  
  if (search) {
    query = query.or(`title.ilike.%${search}%,content.ilike.%${search}%`)
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

// 获取分类列表
async function getCategories() {
  const { data, error } = await supabase
    .from('forum_categories')
    .select('*')
    .eq('is_active', true)
    .order('sort_order')
    .order('name')

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 获取用户帖子
async function getUserPosts(userId: string, req: Request) {
  const url = new URL(req.url)
  const page = parseInt(url.searchParams.get('page') || '1')
  const limit = parseInt(url.searchParams.get('limit') || '10')
  const includeDrafts = url.searchParams.get('drafts') === 'true'
  
  const offset = (page - 1) * limit
  
  let query = supabase
    .from('forum_posts')
    .select(`
      *,
      category:forum_categories(name, slug)
    `, { count: 'exact' })
    .eq('author_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (!includeDrafts) {
    query = query.eq('status', 'published')
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

// 获取用户收藏
async function getUserFavorites(userId: string) {
  const { data, error } = await supabase
    .from('user_favorites')
    .select(`
      *,
      post:forum_posts(
        *,
        author:auth.users(email),
        category:forum_categories(name, slug)
      )
    `)
    .eq('user_id', userId)
    .order('created_at', { ascending: false })

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 获取用户通知
async function getUserNotifications(userId: string, req: Request) {
  const url = new URL(req.url)
  const unread = url.searchParams.get('unread') === 'true'
  const page = parseInt(url.searchParams.get('page') || '1')
  const limit = parseInt(url.searchParams.get('limit') || '20')
  
  const offset = (page - 1) * limit
  
  let query = supabase
    .from('forum_notifications')
    .select(`
      *,
      from_user:auth.users(email, raw_user_meta_data)
    `, { count: 'exact' })
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (unread) {
    query = query.eq('is_read', false)
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

// 获取论坛统计
async function getForumStats() {
  const { data, error } = await supabase
    .from('forum_stats')
    .select('*')
    .limit(1)
    .single()

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 创建帖子
async function createPost(body: any, user: any) {
  const { title, content, category_id, post_type, resource_type, resource_url, resource_description, tags } = body
  
  // 基本验证
  if (!title || !content || !category_id) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  // 检查分类是否存在
  const { data: category } = await supabase
    .from('forum_categories')
    .select('id')
    .eq('id', category_id)
    .single()

  if (!category) {
    return Response.json({ error: 'Invalid category' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('forum_posts')
    .insert({
      title,
      content,
      summary: content.substring(0, 200),
      category_id,
      author_id: user.id,
      post_type: post_type || 'discussion',
      resource_type,
      resource_url,
      resource_description,
      tags: tags || [],
      status: 'published',
      published_at: new Date().toISOString()
    })
    .select()
    .single()

  if (error) {
    throw error
  }

  // 更新统计数据
  await updateForumStats()

  return Response.json({ data }, { headers: corsHeaders })
}

// 创建评论
async function createComment(body: any, user: any) {
  const { post_id, content, parent_id } = body
  
  if (!post_id || !content) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  // 检查帖子是否存在
  const { data: post } = await supabase
    .from('forum_posts')
    .select('id')
    .eq('id', post_id)
    .eq('status', 'published')
    .single()

  if (!post) {
    return Response.json({ error: 'Post not found' }, { 
      status: 404, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('forum_comments')
    .insert({
      post_id,
      user_id: user.id,
      parent_id: parent_id || null,
      content
    })
    .select()
    .single()

  if (error) {
    throw error
  }

  // 增加帖子的评论数
  await supabase.rpc('increment_comment_count', { post_id })

  // 创建通知（如果评论的不是自己的帖子）
  if (post.author_id !== user.id) {
    await supabase
      .from('forum_notifications')
      .insert({
        user_id: post.author_id,
        type: parent_id ? 'reply' : 'comment',
        title: parent_id ? '有人回复了你的评论' : '有人评论了你的帖子',
        content: content.substring(0, 100),
        post_id,
        comment_id: data.id,
        from_user_id: user.id
      })
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 帖子点赞
async function likePost(body: any, user: any) {
  const { post_id } = body
  
  if (!post_id) {
    return Response.json({ error: 'Missing post_id' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  // 检查帖子是否存在
  const { data: post } = await supabase
    .from('forum_posts')
    .select('id, author_id')
    .eq('id', post_id)
    .eq('status', 'published')
    .single()

  if (!post) {
    return Response.json({ error: 'Post not found' }, { 
      status: 404, 
      headers: corsHeaders 
    })
  }

  // 添加点赞记录
  const { error } = await supabase
    .from('forum_likes')
    .insert({
      user_id: user.id,
      post_id
    })

  if (error && !error.message.includes('duplicate')) {
    throw error
  }

  // 增加帖子的点赞数
  await supabase.rpc('increment_like_count', { post_id })

  // 创建通知（如果点赞的不是自己的帖子）
  if (post.author_id !== user.id) {
    await supabase
      .from('forum_notifications')
      .insert({
        user_id: post.author_id,
        type: 'like',
        title: '你的帖子收到了新的点赞',
        post_id,
        from_user_id: user.id
      })
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 评论点赞
async function likeComment(body: any, user: any) {
  const { comment_id } = body
  
  if (!comment_id) {
    return Response.json({ error: 'Missing comment_id' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { error } = await supabase
    .from('comment_likes')
    .insert({
      user_id: user.id,
      comment_id
    })

  if (error && !error.message.includes('duplicate')) {
    throw error
  }

  // 增加评论的点赞数
  await supabase.rpc('increment_comment_like_count', { comment_id })

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 添加收藏
async function addFavorite(body: any, user: any) {
  const { post_id } = body
  
  if (!post_id) {
    return Response.json({ error: 'Missing post_id' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { error } = await supabase
    .from('user_favorites')
    .insert({
      user_id: user.id,
      post_id
    })

  if (error && !error.message.includes('duplicate')) {
    throw error
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 提交反馈
async function submitFeedback(body: any, user: any) {
  const { feedback_type, title, content, priority } = body
  
  if (!feedback_type || !title || !content) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('user_feedback')
    .insert({
      user_id: user.id,
      feedback_type,
      title,
      content,
      priority: priority || 'medium'
    })
    .select()
    .single()

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 标记通知为已读
async function markNotificationsRead(body: any, user: any) {
  const { notification_ids } = body
  
  if (!notification_ids || !Array.isArray(notification_ids)) {
    return Response.json({ error: 'Missing notification_ids' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  const { error } = await supabase
    .from('forum_notifications')
    .update({ is_read: true })
    .eq('user_id', user.id)
    .in('id', notification_ids)

  if (error) {
    throw error
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 更新帖子
async function updatePost(body: any, user: any) {
  const { id, title, content, category_id, tags } = body
  
  if (!id || !title || !content) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  // 检查是否有权限编辑
  const { data: post } = await supabase
    .from('forum_posts')
    .select('id')
    .eq('id', id)
    .eq('author_id', user.id)
    .single()

  if (!post) {
    return Response.json({ error: 'Post not found or no permission' }, { 
      status: 403, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('forum_posts')
    .update({
      title,
      content,
      summary: content.substring(0, 200),
      category_id,
      tags,
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

// 更新评论
async function updateComment(body: any, user: any) {
  const { id, content } = body
  
  if (!id || !content) {
    return Response.json({ error: 'Missing required fields' }, { 
      status: 400, 
      headers: corsHeaders 
    })
  }

  // 检查是否有权限编辑
  const { data: comment } = await supabase
    .from('forum_comments')
    .select('id')
    .eq('id', id)
    .eq('user_id', user.id)
    .single()

  if (!comment) {
    return Response.json({ error: 'Comment not found or no permission' }, { 
      status: 403, 
      headers: corsHeaders 
    })
  }

  const { data, error } = await supabase
    .from('forum_comments')
    .update({
      content,
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

// 更新用户偏好设置
async function updateUserPreferences(body: any, user: any) {
  const { email_notifications, push_notifications, show_email, bio, signature, avatar_url } = body

  const { data, error } = await supabase
    .from('user_forum_preferences')
    .upsert({
      user_id: user.id,
      email_notifications,
      push_notifications,
      show_email,
      bio,
      signature,
      avatar_url,
      updated_at: new Date().toISOString()
    })
    .select()
    .single()

  if (error) {
    throw error
  }

  return Response.json({ data }, { headers: corsHeaders })
}

// 删除帖子
async function deletePost(id: number, user: any) {
  const { error } = await supabase
    .from('forum_posts')
    .delete()
    .eq('id', id)
    .eq('author_id', user.id)

  if (error) {
    throw error
  }

  await updateForumStats()

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 删除评论
async function deleteComment(id: number, user: any) {
  const { error } = await supabase
    .from('forum_comments')
    .delete()
    .eq('id', id)
    .eq('user_id', user.id)

  if (error) {
    throw error
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 取消帖子点赞
async function unlikePost(id: number, user: any) {
  const { error } = await supabase
    .from('forum_likes')
    .delete()
    .eq('post_id', id)
    .eq('user_id', user.id)

  if (error) {
    throw error
  }

  // 减少帖子的点赞数
  await supabase.rpc('decrement_like_count', { post_id: id })

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 移除收藏
async function removeFavorite(id: number, user: any) {
  const { error } = await supabase
    .from('user_favorites')
    .delete()
    .eq('post_id', id)
    .eq('user_id', user.id)

  if (error) {
    throw error
  }

  return Response.json({ success: true }, { headers: corsHeaders })
}

// 更新论坛统计数据
async function updateForumStats() {
  const postsResult = await supabase
    .from('forum_posts')
    .select('id', { count: 'exact' })
    .eq('status', 'published')
  
  const commentsResult = await supabase
    .from('forum_comments')
    .select('id', { count: 'exact' })
    .eq('status', 'published')

  const { error } = await supabase
    .from('forum_stats')
    .update({
      total_posts: postsResult.count || 0,
      total_comments: commentsResult.count || 0,
      last_updated: new Date().toISOString()
    })
    .lt('id', 2) // 更新ID为1的记录

  if (error) {
    console.error('Error updating forum stats:', error)
  }
}