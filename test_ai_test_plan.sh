#!/bin/bash

# AI 出题系统测试脚本
# 使用 curl 直接调用 Supabase Edge Function

set -e  # 遇到错误立即退出

# ═══════════════════════════════════════════════════════════
# 配置
# ═══════════════════════════════════════════════════════════
SUPABASE_URL="https://tqehcadjuwodbmgmxzmf.supabase.co"
# 使用 anon key（公开的，可以调用 Edge Function）
ANON_KEY="sb_publishable_aKICDtmL2aisDtOpNh88jQ_IZ3m_fuB"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 AI 出题系统测试脚本${NC}"
echo "============================================================"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 1: 列出所有字幕文件，找到一个可用的视频资源
# ═══════════════════════════════════════════════════════════
echo -e "${YELLOW}Step 1: 查找有字幕的视频资源...${NC}"

# 注意：list 操作需要用户 token，这里我们用一个 workaround
# 直接尝试一个常见的 video_code 或者从数据库查询

# 先尝试获取用户列表（需要 service_role）
echo -e "${BLUE}尝试获取用户信息...${NC}"
USERS_RESPONSE=$(curl -s -X GET \
  "${SUPABASE_URL}/rest/v1/users?limit=1" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  2>&1)

echo "Users API Response: $USERS_RESPONSE" | head -c 200
echo ""

# 如果上面的方法不行，我们直接使用一个固定的 test user ID
# TODO: 替换为真实的用户 ID
TEST_USER_ID="test-user-id"

echo ""
echo -e "${YELLOW}使用测试用户 ID: ${TEST_USER_ID}${NC}"

# ═══════════════════════════════════════════════════════════
# Step 2: 调用 subtitle-storage list 获取字幕列表
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${YELLOW}Step 2: 获取字幕文件列表...${NC}"

SUBTITLE_LIST=$(curl -s -X POST \
  "${SUPABASE_URL}/functions/v1/subtitle-storage" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "op": "list",
    "folder_code": ""
  }' 2>&1)

echo "Subtitle List Response:"
echo "$SUBTITLE_LIST" | python3 -m json.tool 2>/dev/null || echo "$SUBTITLE_LIST"

# 从响应中提取第一个 video_code
VIDEO_CODE=$(echo "$SUBTITLE_LIST" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('ok') and data.get('files'):
        print(data['files'][0]['video_code'])
    else:
        print('')
except:
    print('')
" 2>/dev/null)

if [ -z "$VIDEO_CODE" ]; then
    echo -e "${RED}❌ 无法获取视频 code，使用默认值测试${NC}"
    VIDEO_CODE="test_video_001"
else
    echo -e "${GREEN}✅ 选择视频: ${VIDEO_CODE}${NC}"
fi

# ═══════════════════════════════════════════════════════════
# Step 3: 调用 ai-test-plan 生成题目
# ═══════════════════════════════════════════════════════════
echo ""
echo "============================================================"
echo -e "${YELLOW}Step 3: 测试 AI 出题功能${NC}"
echo "============================================================"
echo ""
echo -e "${BLUE}视频 Code: ${VIDEO_CODE}${NC}"
echo ""

REQUEST_BODY=$(cat <<EOF
{
  "request_id": "test_$(date +%s)",
  "video_code": "${VIDEO_CODE}",
  "source_type": "resource",
  "difficulty": "intermediate",
  "config": {
    "listen_choose_count": 1,
    "listen_meaning_count": 1,
    "listen_reply_count": 0,
    "definition_choice_count": 1,
    "spelling_count": 1,
    "reorder_count": 1,
    "translate_meaning_count": 1,
    "word_relation_count": 0,
    "word_pron_count": 0,
    "phrase_pron_count": 0,
    "sentence_pron_count": 0,
    "mcq_count": 1
  }
}
EOF
)

echo -e "${BLUE}📤 请求体:${NC}"
echo "$REQUEST_BODY" | python3 -m json.tool
echo ""

echo -e "${BLUE}🌐 调用 ai-test-plan Edge Function...${NC}"
START_TIME=$(date +%s%N)  # 纳秒时间戳

RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/functions/v1/ai-test-plan" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" 2>&1)

END_TIME=$(date +%s%N)
DURATION=$(( (END_TIME - START_TIME) / 1000000 ))  # 转换为毫秒

echo -e "${GREEN}📥 响应 (耗时 ${DURATION}ms):${NC}"
echo ""

# 格式化 JSON 输出
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

echo ""
echo "============================================================"

# ═══════════════════════════════════════════════════════════
# Step 4: 分析结果
# ═══════════════════════════════════════════════════════════
echo -e "${YELLOW}Step 4: 结果分析${NC}"
echo ""

# 解析响应
OK=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('true' if data.get('ok') else 'false')
except:
    print('false')
" 2>/dev/null)

if [ "$OK" = "true" ]; then
    echo -e "${GREEN}✅ 出题成功!${NC}"
    
    # 提取关键信息
    TITLE=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('title', 'N/A'))
" 2>/dev/null)
    
    ITEMS_COUNT=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('plan', {}).get('items', [])
print(len(items))
" 2>/dev/null)
    
    BILLING_RULE=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
billing = data.get('billing', {})
print(billing.get('rule_code', 'N/A'))
" 2>/dev/null)
    
    echo "   标题: $TITLE"
    echo "   题目数量: $ITEMS_COUNT"
    echo "   计费规则: $BILLING_RULE"
    
    # 打印题目详情
    if [ "$ITEMS_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${BLUE}📊 生成的题目详情:${NC}"
        echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('plan', {}).get('items', [])

for i, item in enumerate(items, 1):
    item_type = item.get('type', 'unknown')
    ref_text = item.get('ref_text') or item.get('sentence') or item.get('display_text') or item.get('masked') or 'N/A'
    
    # 截断过长的文本
    if len(ref_text) > 60:
        ref_text = ref_text[:60] + '...'
    
    print(f'\n   【题目 {i}】{item_type}')
    print(f'   参考文本: {ref_text}')
    
    # 选项
    options = item.get('options')
    if options:
        opts_str = ', '.join(str(o)[:20] for o in options[:4])
        print(f'   选项: {opts_str}')
    
    # 答案
    answer = item.get('answer')
    if answer:
        print(f'   答案: {answer}')
" 2>/dev/null
    fi
    
else
    ERROR_CODE=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('error', 'unknown'))
" 2>/dev/null)
    
    ERROR_MSG=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('message', 'No message'))
" 2>/dev/null)
    
    echo -e "${RED}❌ 出题失败!${NC}"
    echo "   错误码: $ERROR_CODE"
    echo "   错误信息: $ERROR_MSG"
fi

echo ""
echo "============================================================"
echo -e "${BLUE}🎉 测试完成${NC}"
echo ""
echo "💡 提示:"
echo "   - 如果看到 'no_content' 错误，说明该视频没有上传字幕"
echo "   - 如果看到 'unauthorized' 错误，说明 Service Role Key 无效"
echo "   - 如果看到 'insufficient_balance' 错误，说明余额不足"
echo "   - 查看完整日志可以定位具体问题"
echo ""
