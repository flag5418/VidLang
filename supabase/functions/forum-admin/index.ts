import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'

// 简单的管理后台 HTML 页面路由
// 返回内联的基础 HTML 页面（生产环境可替换为完整前端构建产物）

const PAGES: Record<string, string> = {
  login: `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VidLang 论坛管理后台</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; display:flex; justify-content:center; align-items:center; min-height:100vh; }
    .login-box { background:#fff; padding:40px; border-radius:12px; box-shadow:0 2px 12px rgba(0,0,0,.08); width:400px; max-width:90vw; }
    h1 { text-align:center; margin-bottom:32px; color:#333; font-size:24px; }
    label { display:block; margin-bottom:6px; color:#555; font-size:14px; }
    input { width:100%; padding:12px; margin-bottom:20px; border:1px solid #ddd; border-radius:8px; font-size:14px; }
    button { width:100%; padding:12px; background:#4f46e5; color:#fff; border:none; border-radius:8px; font-size:16px; cursor:pointer; }
    button:hover { background:#4338ca; }
    .error { color:#ef4444; text-align:center; margin-top:12px; font-size:13px; display:none; }
  </style>
</head>
<body>
  <div class="login-box">
    <h1>论坛管理后台</h1>
    <form id="loginForm">
      <label>邮箱</label>
      <input type="email" id="email" placeholder="admin@vidlang.com" required>
      <label>密码</label>
      <input type="password" id="password" placeholder="••••••••" required>
      <button type="submit">登 录</button>
      <p class="error" id="error"></p>
    </form>
  </div>
  <script>
    document.getElementById('loginForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('email').value;
      const password = document.getElementById('password').value;
      const errEl = document.getElementById('error');
      try {
        const res = await fetch('/forum-admin-auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password }),
        });
        const data = await res.json();
        if (res.ok) {
          localStorage.setItem('admin_token', data.token);
          localStorage.setItem('admin_user', JSON.stringify(data.user));
          window.location.href = '/forum-admin/dashboard';
        } else {
          errEl.textContent = data.error || '登录失败';
          errEl.style.display = 'block';
        }
      } catch {
        errEl.textContent = '网络错误';
        errEl.style.display = 'block';
      }
    });
  </script>
</body>
</html>`,

  dashboard: `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>仪表盘 - VidLang 管理后台</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background:#f5f5f5; display:flex; min-height:100vh; }
    nav { width:220px; background:#1e1b4b; color:#fff; padding:20px 0; }
    nav a { display:block; padding:12px 24px; color:#c7d2fe; text-decoration:none; font-size:14px; }
    nav a:hover, nav a.active { background:#312e81; color:#fff; }
    main { flex:1; padding:32px; }
    h2 { margin-bottom:24px; color:#333; }
    .stats { display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:16px; margin-bottom:32px; }
    .stat-card { background:#fff; padding:20px; border-radius:10px; box-shadow:0 1px 6px rgba(0,0,0,.06); }
    .stat-card .num { font-size:28px; font-weight:700; color:#4f46e5; }
    .stat-card .label { font-size:13px; color:#888; margin-top:4px; }
  </style>
</head>
<body>
  <nav>
    <div style="padding:12px 24px 24px;font-weight:700;">VidLang 管理</div>
    <a href="/forum-admin/dashboard" class="active">仪表盘</a>
    <a href="/forum-admin/posts">帖子管理</a>
    <a href="/forum-admin/reports">举报管理</a>
    <a href="/forum-admin/users">用户管理</a>
    <a href="/forum-admin/feedback">反馈管理</a>
    <a href="/forum-admin/boards">板块管理</a>
    <a href="#" onclick="logout()" style="margin-top:16px;color:#f87171;">退出登录</a>
  </nav>
  <main>
    <h2>仪表盘</h2>
    <div class="stats" id="stats"></div>
  </main>
  <script>
    // 验证登录
    const token = localStorage.getItem('admin_token');
    if (!token) { window.location.href = '/forum-admin/login'; }

    function logout() { localStorage.clear(); window.location.href = '/forum-admin/login'; }

    async function loadDashboard() {
      const res = await fetch('/forum-admin-dashboard', { headers: { Authorization: 'Bearer ' + token } });
      if (!res.ok) { logout(); return; }
      const { data } = await res.json();
      document.getElementById('stats').innerHTML = [
        { label:'总用户数', num: data.total_users },
        { label:'帖子总数', num: data.total_posts },
        { label:'今日新帖', num: data.today_posts },
        { label:'回复总数', num: data.total_replies },
        { label:'今日新回复', num: data.today_replies },
        { label:'待处理举报', num: data.pending_reports },
        { label:'待处理反馈', num: data.pending_feedback },
        { label:'被封禁用户', num: data.banned_users },
      ].map(s => '<div class="stat-card"><div class="num">'+s.num+'</div><div class="label">'+s.label+'</div></div>').join('');
    }
    loadDashboard();
  </script>
</body>
</html>`,

  posts: `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <title>帖子管理 - VidLang 管理后台</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background:#f5f5f5; display:flex; min-height:100vh; }
    nav { width:220px; background:#1e1b4b; color:#fff; padding:20px 0; }
    nav a { display:block; padding:12px 24px; color:#c7d2fe; text-decoration:none; font-size:14px; }
    nav a:hover, nav a.active { background:#312e81; color:#fff; }
    main { flex:1; padding:32px; }
    h2 { margin-bottom:24px; color:#333; }
    table { width:100%; background:#fff; border-radius:10px; overflow:hidden; box-shadow:0 1px 6px rgba(0,0,0,.06); }
    th, td { padding:12px 16px; text-align:left; border-bottom:1px solid #f0f0f0; font-size:14px; }
    th { background:#fafafa; color:#555; font-weight:600; }
    button { padding:4px 12px; border-radius:4px; border:1px solid #ddd; cursor:pointer; font-size:12px; margin:0 2px; }
    .pin { background:#fef3c7; color:#92400e; }
    .essence { background:#ede9fe; color:#5b21b6; }
    .del { background:#fee2e2; color:#991b1b; }
  </style>
</head>
<body>
  <nav>
    <div style="padding:12px 24px 24px;font-weight:700;">VidLang 管理</div>
    <a href="/forum-admin/dashboard">仪表盘</a>
    <a href="/forum-admin/posts" class="active">帖子管理</a>
    <a href="/forum-admin/reports">举报管理</a>
    <a href="/forum-admin/users">用户管理</a>
    <a href="/forum-admin/feedback">反馈管理</a>
    <a href="/forum-admin/boards">板块管理</a>
    <a href="#" onclick="logout()" style="margin-top:16px;color:#f87171;">退出登录</a>
  </nav>
  <main>
    <h2>帖子管理</h2>
    <div id="content">加载中...</div>
  </main>
  <script>
    const token = localStorage.getItem('admin_token');
    if (!token) { window.location.href = '/forum-admin/login'; }
    function logout() { localStorage.clear(); window.location.href = '/forum-admin/login'; }
    async function load() {
      const res = await fetch('/forum-admin-posts?limit=50', { headers: { Authorization: 'Bearer ' + token } });
      if (!res.ok) { logout(); return; }
      const { data } = await res.json();
      const rows = data.map(p => '<tr><td>'+p.title+'</td><td>'+p.board?.name+'</td><td>'+p.reply_count+'</td><td>'+new Date(p.created_at).toLocaleDateString()+'</td><td>'+
        '<button class="pin" onclick="togglePin('+p.id+','+p.is_pinned+')">'+(p.is_pinned?'取消置顶':'置顶')+'</button>'+
        '<button class="essence" onclick="toggleEssence('+p.id+','+p.is_essence+')">'+(p.is_essence?'取消加精':'加精')+'</button>'+
        '<button class="del" onclick="delPost('+p.id+')">删除</button></td></tr>').join('');
      document.getElementById('content').innerHTML = '<table><thead><tr><th>标题</th><th>板块</th><th>回复</th><th>创建时间</th><th>操作</th></tr></thead><tbody>'+rows+'</tbody></table>';
    }
    load();
    async function togglePin(id, current) {
      await fetch('/forum-admin-posts/'+id+'/pin', { method:'PUT', headers:{ Authorization:'Bearer '+token } });
      load();
    }
    async function toggleEssence(id, current) {
      await fetch('/forum-admin-posts/'+id+'/essence', { method:'PUT', headers:{ Authorization:'Bearer '+token } });
      load();
    }
    async function delPost(id) {
      if (!confirm('确认删除？')) return;
      await fetch('/forum-admin-posts/'+id, { method:'PUT', headers:{ Authorization:'Bearer '+token, 'Content-Type':'application/json' }, body: JSON.stringify({is_deleted:true, deleted_reason:'Admin deleted'}) });
      load();
    }
  </script>
</body>
</html>`,

  reports: `<!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><title>举报管理</title>
  <style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f5f5f5;display:flex;min-height:100vh}nav{width:220px;background:#1e1b4b;color:#fff;padding:20px 0}nav a{display:block;padding:12px 24px;color:#c7d2fe;text-decoration:none;font-size:14px}nav a:hover,nav a.active{background:#312e81;color:#fff}main{flex:1;padding:32px}h2{margin-bottom:24px}table{width:100%;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 1px 6px rgba(0,0,0,.06)}th,td{padding:12px 16px;text-align:left;border-bottom:1px solid #f0f0f0;font-size:14px}th{background:#fafafa;color:#555}button{padding:4px 12px;border-radius:4px;border:1px solid #ddd;cursor:pointer;font-size:12px}.res{background:#d1fae5;color:#065f46}.dis{background:#fee2e2;color:#991b1b}</style>
</head>
<body>
  <nav><div style="padding:12px 24px 24px;font-weight:700">VidLang管理</div><a href="/forum-admin/dashboard">仪表盘</a><a href="/forum-admin/posts">帖子管理</a><a href="/forum-admin/reports" class="active">举报管理</a><a href="/forum-admin/users">用户管理</a><a href="/forum-admin/feedback">反馈管理</a><a href="/forum-admin/boards">板块管理</a><a href="#" onclick="logout()" style="margin-top:16px;color:#f87171">退出</a></nav>
  <main><h2>举报管理</h2><div id="content">加载中...</div></main>
  <script>
    const token=localStorage.getItem('admin_token');if(!token)location.href='/forum-admin/login';
    function logout(){localStorage.clear();location.href='/forum-admin/login'}
    async function load(){
      const res=await fetch('/forum-admin-reports?status=pending&limit=50',{headers:{Authorization:'Bearer '+token}});
      if(!res.ok){logout();return}
      const {data}=await res.json();
      document.getElementById('content').innerHTML='<table><thead><tr><th>类型</th><th>原因</th><th>详情</th><th>时间</th><th>操作</th></tr></thead><tbody>'+data.map(r=>'<tr><td>'+r.target_type+' #'+r.target_id+'</td><td>'+r.reason+'</td><td>'+r.detail.substring(0,50)+'</td><td>'+new Date(r.created_at).toLocaleDateString()+'</td><td><button class="res" onclick="resolve('+r.id+')">处理</button><button class="dis" onclick="dismiss('+r.id+')">忽略</button></td></tr>').join('')+'</tbody></table>';
    }
    load();
    async function resolve(id){await fetch('/forum-admin-reports/'+id+'/resolve',{method:'PUT',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({resolution:'Handled by admin'})});load()}
    async function dismiss(id){await fetch('/forum-admin-reports/'+id+'/dismiss',{method:'PUT',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'}});load()}
  </script>
</body>
</html>`,

  users: `<!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><title>用户管理</title>
  <style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f5f5f5;display:flex;min-height:100vh}nav{width:220px;background:#1e1b4b;color:#fff;padding:20px 0}nav a{display:block;padding:12px 24px;color:#c7d2fe;text-decoration:none;font-size:14px}nav a:hover,nav a.active{background:#312e81;color:#fff}main{flex:1;padding:32px}h2{margin-bottom:24px}table{width:100%;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 1px 6px rgba(0,0,0,.06)}th,td{padding:12px 16px;text-align:left;border-bottom:1px solid #f0f0f0;font-size:14px}th{background:#fafafa;color:#555}button{padding:4px 12px;border-radius:4px;border:1px solid #ddd;cursor:pointer;font-size:12px;margin:0 2px}.ban{background:#fee2e2;color:#991b1b}.unban{background:#d1fae5;color:#065f46}</style>
</head>
<body>
  <nav><div style="padding:12px 24px 24px;font-weight:700">VidLang管理</div><a href="/forum-admin/dashboard">仪表盘</a><a href="/forum-admin/posts">帖子管理</a><a href="/forum-admin/reports">举报管理</a><a href="/forum-admin/users" class="active">用户管理</a><a href="/forum-admin/feedback">反馈管理</a><a href="/forum-admin/boards">板块管理</a><a href="#" onclick="logout()" style="margin-top:16px;color:#f87171">退出</a></nav>
  <main><h2>用户管理</h2><div id="content">加载中...</div></main>
  <script>
    const token=localStorage.getItem('admin_token');if(!token)location.href='/forum-admin/login';
    function logout(){localStorage.clear();location.href='/forum-admin/login'}
    async function load(){
      const res=await fetch('/forum-admin-users?limit=50',{headers:{Authorization:'Bearer '+token}});
      if(!res.ok){logout();return}
      const {data}=await res.json();
      document.getElementById('content').innerHTML='<table><thead><tr><th>邮箱</th><th>角色</th><th>注册时间</th><th>状态</th><th>操作</th></tr></thead><tbody>'+data.map(u=>'<tr><td>'+u.email+'</td><td>'+u.role+'</td><td>'+new Date(u.created_at).toLocaleDateString()+'</td><td>'+(u.ban?'封禁中':'正常')+'</td><td>'+(u.ban?'<button class="unban" onclick="unban(\''+u.id+'\')">解封</button>':'<button class="ban" onclick="ban(\''+u.id+'\')">封禁</button>')+'</td></tr>').join('')+'</tbody></table>';
    }
    load();
    async function ban(uid){const d=prompt('封禁天数（0=永久）：','7');if(!d&&d!=='0')return;await fetch('/forum-admin-users/'+uid+'/ban',{method:'PUT',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({reason:'违反社区规定',duration_days:parseInt(d)})});load()}
    async function unban(uid){await fetch('/forum-admin-users/'+uid+'/unban',{method:'PUT',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'}});load()}
  </script>
</body>
</html>`,

  feedback: `<!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><title>反馈管理</title>
  <style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f5f5f5;display:flex;min-height:100vh}nav{width:220px;background:#1e1b4b;color:#fff;padding:20px 0}nav a{display:block;padding:12px 24px;color:#c7d2fe;text-decoration:none;font-size:14px}nav a:hover,nav a.active{background:#312e81;color:#fff}main{flex:1;padding:32px}h2{margin-bottom:24px}table{width:100%;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 1px 6px rgba(0,0,0,.06)}th,td{padding:12px 16px;text-align:left;border-bottom:1px solid #f0f0f0;font-size:14px}th{background:#fafafa;color:#555}button{padding:4px 12px;border-radius:4px;border:1px solid #ddd;cursor:pointer;font-size:12px}.pro{background:#fef3c7;color:#92400e}.res{background:#d1fae5;color:#065f46}</style>
</head>
<body>
  <nav><div style="padding:12px 24px 24px;font-weight:700">VidLang管理</div><a href="/forum-admin/dashboard">仪表盘</a><a href="/forum-admin/posts">帖子管理</a><a href="/forum-admin/reports">举报管理</a><a href="/forum-admin/users">用户管理</a><a href="/forum-admin/feedback" class="active">反馈管理</a><a href="/forum-admin/boards">板块管理</a><a href="#" onclick="logout()" style="margin-top:16px;color:#f87171">退出</a></nav>
  <main><h2>反馈管理</h2><div id="content">加载中...</div></main>
  <script>
    const token=localStorage.getItem('admin_token');if(!token)location.href='/forum-admin/login';
    function logout(){localStorage.clear();location.href='/forum-admin/login'}
    async function load(){
      const res=await fetch('/forum-admin-feedback?status=all&limit=50',{headers:{Authorization:'Bearer '+token}});
      if(!res.ok){logout();return}
      const {data}=await res.json();
      document.getElementById('content').innerHTML='<table><thead><tr><th>类型</th><th>标题</th><th>状态</th><th>时间</th><th>操作</th></tr></thead><tbody>'+data.map(f=>'<tr><td>'+f.type+'</td><td>'+f.title+'</td><td>'+f.status+'</td><td>'+new Date(f.created_at).toLocaleDateString()+'</td><td>'+(f.status==='pending'?'<button class="pro" onclick="processing('+f.id+')">处理中</button><button class="res" onclick="resolve('+f.id+')">已解决</button>':'')+'</td></tr>').join('')+'</tbody></table>';
    }
    load();
    async function processing(id){await fetch('/forum-admin-feedback/'+id,{method:'PUT',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({status:'processing'})});load()}
    async function resolve(id){await fetch('/forum-admin-feedback/'+id,{method:'PUT',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({status:'resolved'})});load()}
  </script>
</body>
</html>`,

  boards: `<!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><title>板块管理</title>
  <style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f5f5f5;display:flex;min-height:100vh}nav{width:220px;background:#1e1b4b;color:#fff;padding:20px 0}nav a{display:block;padding:12px 24px;color:#c7d2fe;text-decoration:none;font-size:14px}nav a:hover,nav a.active{background:#312e81;color:#fff}main{flex:1;padding:32px}h2{margin-bottom:24px}table{width:100%;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 1px 6px rgba(0,0,0,.06)}th,td{padding:12px 16px;text-align:left;border-bottom:1px solid #f0f0f0;font-size:14px}th{background:#fafafa;color:#555}button{padding:4px 12px;border-radius:4px;border:1px solid #ddd;cursor:pointer;font-size:12px;margin:0 2px}.edit{background:#ede9fe;color:#5b21b6}.del{background:#fee2e2;color:#991b1b}</style>
</head>
<body>
  <nav><div style="padding:12px 24px 24px;font-weight:700">VidLang管理</div><a href="/forum-admin/dashboard">仪表盘</a><a href="/forum-admin/posts">帖子管理</a><a href="/forum-admin/reports">举报管理</a><a href="/forum-admin/users">用户管理</a><a href="/forum-admin/feedback">反馈管理</a><a href="/forum-admin/boards" class="active">板块管理</a><a href="#" onclick="logout()" style="margin-top:16px;color:#f87171">退出</a></nav>
  <main><h2>板块管理</h2><div id="content">加载中...</div></main>
  <script>
    const token=localStorage.getItem('admin_token');if(!token)location.href='/forum-admin/login';
    function logout(){localStorage.clear();location.href='/forum-admin/login'}
    async function load(){
      const res=await fetch('/forum-admin-boards',{headers:{Authorization:'Bearer '+token}});
      if(!res.ok){logout();return}
      const {data}=await res.json();
      document.getElementById('content').innerHTML='<table><thead><tr><th>名称</th><th>Slug</th><th>排序</th><th>状态</th><th>操作</th></tr></thead><tbody>'+data.map(b=>'<tr><td>'+b.name+'</td><td>'+b.slug+'</td><td>'+b.sort_order+'</td><td>'+(b.is_active?'启用':'禁用')+'</td><td><button class="edit" onclick="editBoard('+b.id+')">编辑</button>'+(b.is_active?'<button class="del" onclick="toggleActive('+b.id+',false)">隐藏</button>':'<button onclick="toggleActive('+b.id+',true)">启用</button>')+'</td></tr>').join('')+'</tbody></table>';
    }
    load();
    async function toggleActive(id,active){await fetch('/forum-admin-boards/'+id,{method:'PUT',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({is_active:active})});load()}
    function editBoard(id){alert('编辑功能请直接调用 API：PUT /forum-admin-boards/'+id)}
  </script>
</body>
</html>`,
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url);
    // 路径 /forum-admin/ 后面跟的是页面路径
    const path = url.pathname.replace('/forum-admin', '').replace(/^\//, '');

    // 根路径重定向到 login
    if (!path) {
      return new Response(null, { status: 302, headers: { ...corsHeaders, Location: '/forum-admin/login' } });
    }

    const page = PAGES[path];
    if (page) {
      return new Response(page, {
        headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
      });
    }

    return new Response('Page not found', { status: 404, headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' } });
  } catch (error) {
    console.error('forum-admin error:', error);
    return new Response('Internal server error', { status: 500, headers: corsHeaders });
  }
});
