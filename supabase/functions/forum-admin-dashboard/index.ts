import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'
import { verifyAdmin } from '../_shared/admin-auth.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders });
    }
    const admin = await verifyAdmin(authHeader.replace('Bearer ', ''));
    if (!admin) {
      return Response.json({ error: 'No admin permission' }, { status: 403, headers: corsHeaders });
    }

    if (req.method !== 'GET') {
      return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
    }

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const weekStart = new Date();
    weekStart.setDate(weekStart.getDate() - 7);
    weekStart.setHours(0, 0, 0, 0);

    // 用户总数
    const { count: totalUsers } = await supabase
      .from('user_profiles')
      .select('id', { count: 'exact', head: true });

    // 帖子总数
    const { count: totalPosts } = await supabase
      .from('forum_posts')
      .select('id', { count: 'exact', head: true })
      .eq('is_deleted', false);

    // 今日新帖
    const { count: todayPosts } = await supabase
      .from('forum_posts')
      .select('id', { count: 'exact', head: true })
      .eq('is_deleted', false)
      .gte('created_at', todayStart.toISOString());

    // 本周新帖
    const { count: weekPosts } = await supabase
      .from('forum_posts')
      .select('id', { count: 'exact', head: true })
      .eq('is_deleted', false)
      .gte('created_at', weekStart.toISOString());

    // 回复总数
    const { count: totalReplies } = await supabase
      .from('forum_replies')
      .select('id', { count: 'exact', head: true })
      .eq('is_deleted', false);

    // 今日新回复
    const { count: todayReplies } = await supabase
      .from('forum_replies')
      .select('id', { count: 'exact', head: true })
      .eq('is_deleted', false)
      .gte('created_at', todayStart.toISOString());

    // 待处理举报数
    const { count: pendingReports } = await supabase
      .from('forum_reports')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending');

    // 待处理反馈数
    const { count: pendingFeedback } = await supabase
      .from('forum_feedback')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending');

    // 被封禁用户数
    const { count: bannedUsers } = await supabase
      .from('user_bans')
      .select('id', { count: 'exact', head: true })
      .eq('is_active', true);

    // 最近7天每日帖子数趋势
    const { data: dailyData } = await supabase
      .from('forum_posts')
      .select('created_at')
      .eq('is_deleted', false)
      .gte('created_at', weekStart.toISOString());

    const dailyPosts: number[] = new Array(7).fill(0);
    if (dailyData) {
      for (const item of dailyData) {
        const day = Math.floor((new Date(item.created_at).getTime() - weekStart.getTime()) / 86400000);
        if (day >= 0 && day < 7) dailyPosts[day]++;
      }
    }

    return Response.json({
      data: {
        total_users: totalUsers || 0,
        total_posts: totalPosts || 0,
        today_posts: todayPosts || 0,
        week_posts: weekPosts || 0,
        total_replies: totalReplies || 0,
        today_replies: todayReplies || 0,
        pending_reports: pendingReports || 0,
        pending_feedback: pendingFeedback || 0,
        banned_users: bannedUsers || 0,
        daily_posts: dailyPosts.map((count, i) => {
          const d = new Date(weekStart);
          d.setDate(d.getDate() + i);
          return { date: d.toISOString().split('T')[0], count };
        }),
      }
    }, { headers: corsHeaders });
  } catch (error) {
    console.error('forum-admin-dashboard error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});
