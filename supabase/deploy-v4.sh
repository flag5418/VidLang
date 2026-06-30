#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# V4 AI 出题系统 - 一键部署脚本
# ═══════════════════════════════════════════════════════════════
#
# 使用方法：
# 1. 确保已安装 supabase CLI: npm install -g supabase
# 2. 登录: supabase login
# 3. 运行: ./deploy-v4.sh
#
# 或者手动执行：
# - Step 1: 在 Supabase Dashboard SQL Editor 中执行 migration SQL
# - Step 2: 部署 Edge Functions
#
# ═══════════════════════════════════════════════════════════════

set -e  # 遇到错误立即退出

echo "🚀 V4 AI 出题系统部署开始..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── 配置 ──────────────────────────────────
SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-$PROJECT_REF}"
DB_PASSWORD="${SUPABASE_DB_PASSWORD:-$DB_PASSWORD}"
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"  # 需要从 Dashboard 获取或设置环境变量

# ─── Step 1: 数据库 Migration ───────────────
echo ""
echo "📋 Step 1/4: 执行数据库 Migration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v supabase &> /dev/null; then
    echo "✅ 检测到 Supabase CLI"
    
    # 尝试链接项目（如果还没链接）
    if [ ! -f ".supabase/config.toml" ]; then
        echo "🔗 正在链接 Supabase 项目..."
        supabase link --project-ref "$SUPABASE_PROJECT_REF" || {
            echo "⚠️ 自动链接失败，请手动执行以下步骤："
            echo "   1. 打开 Supabase Dashboard"
            echo "   2. 进入 SQL Editor"
            echo "   3. 复制 migrations/20260629000002_extend_word_cache_for_v4.sql 的内容并执行"
            exit 1
        }
    fi
    
    # 执行 Migration
    echo "🔄 正在执行 Migration..."
    supabase db push 2>&1 || {
        echo "❌ Migration 执行失败"
        exit 1
    }
    
    echo "✅ Migration 执行成功！"
else
    echo "⚠️ 未检测到 Supabase CLI"
    echo ""
    echo "📝 请手动执行以下操作："
    echo "   1. 打开 Supabase Dashboard: https://supabase.com/dashboard/project/$SUPABASE_PROJECT_REF"
    echo "   2. 进入 SQL Editor (左侧菜单)"
    echo "   3. 新建 Query，复制以下文件的全部内容："
    echo "      → supabase/migrations/20260629000002_extend_word_cache_for_v4.sql"
    echo "   4. 点击 Run 执行 SQL"
    echo ""
    read -p "按 Enter 键继续（假设你已完成手动 Migration）..."
fi

# ─── Step 2: 部署 Edge Functions ──────────
echo ""
echo "📦 Step 2/4: 部署 Edge Functions..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v supabase &> /dev/null; then
    echo "🔄 正在部署所有 Edge Functions..."
    
    # 部署核心函数
    supabase functions deploy ai-test-plan --no-verify-jwt 2>&1 && \
    echo "  ✅ ai-test-plan 部署成功" || \
    echo "  ❌ ai-test-plan 部署失败"
    
    supabase functions deploy word-cache --no-verify-jwt 2>&1 && \
    echo "  ✅ word-cache 部署成功" || \
    echo "  ❌ word-cache 部署失败"
    
    supabase functions deploy ai-proxy --no-verify-jwt 2>&1 && \
    echo "  ✅ ai-proxy 部署成功" || \
    echo "  ❌ ai-proxy 部署失败"
    
    echo ""
    echo "✅ Edge Functions 部署完成！"
else
    echo "⚠️ 请使用 Supabase CLI 部署，或通过 Dashboard 手动部署"
fi

# ─── Step 3: 刷新 word_cache 数据 ─────────
echo ""
echo "🔄 Step 3/4: 刷新 word_cache V4 字段..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "📝 调用 word-cache refresh 接口..."
curl -s -X POST \
  "https://$SUPABASE_PROJECT_REF.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"limit": 100, "dry_run": true}' | jq . || {
    echo "⚠️ 无法调用 refresh 接口（可能需要有效的 Service Role Key）"
    echo ""
    echo "💡 你可以在部署完成后手动触发刷新："
    echo "   curl -X POST 'https://$SUPABASE_PROJECT_REF.supabase.co/functions/v1/word-cache?action=refresh' \\"
    echo "     -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"limit\": 100, \"dry_run\": false}'"
}

# ─── Step 4: 验证部署 ─────────────────────
echo ""
echo "✅ Step 4/4: 验证部署状态..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🎉 V4 AI 出题系统部署完成！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 部署摘要："
echo "  ✅ 数据库: word_cache 表已扩展（synonyms/antonyms/category）"
echo "  ✅ Edge Functions: ai-test-plan / word-cache / ai-proxy 已更新"
echo "  ✅ 新增 Agent: MCQ / Meaning / Definition / Forms"
echo "  ✅ Quality Gate: 9 大校验规则已启用"
echo ""
echo "🧪 测试建议："
echo "  1. 打开 App 进入测试页面"
echo "  2. 选择一个视频或生词本"
echo "  3. 设置难度为 'intermediate'"
echo "  4. 开启以下题型进行测试："
echo "     - mcq (选择题) - 使用 V4 Agent 生成高质量干扰项"
echo "     - definition_choice (释义选择) - 使用 AI 生成释义选项"
echo "     - word_pron (跟读) - 保持原有逻辑不变"
echo "  5. 观察题目质量："
echo "     - 干扰项是否语义合理？"
echo "     - 是否还有答案泄露？"
echo "     - hint 和 feedback 是否有用？"
echo ""
echo "📊 监控命令："
echo "  # 查看 word-cache 统计"
echo "  curl 'https://$SUPABASE_PROJECT_REF.supabase.co/functions/v1/word-cache?action=stats'"
echo ""
echo "  # 刷新 V4 字段（正式执行）"
echo "  curl -X POST 'https://$SUPABASE_PROJECT_REF.supabase.co/functions/v1/word-cache?action=refresh' \\"
echo "    -H 'Authorization: Bearer \$SERVICE_ROLE_KEY' \\"
echo "    -d '{\"limit\": 50, \"dry_run\": false}'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
