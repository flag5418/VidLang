#!/bin/bash

# VidLang 文档同步检查脚本
# 用于检查文档与代码的一致性

set -e

echo "=== VidLang 文档同步检查 ==="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查结果
ERRORS=0
WARNINGS=0

# 检查函数
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description - 文件不存在: $file"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_directory() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description - 目录不存在: $dir"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# 1. 检查核心文档
echo "1. 检查核心文档..."
check_file "AGENTS.md" "AGENTS.md 存在"
check_file "项目全局规则.md" "项目全局规则.md 存在"
check_file "docs/AGENT_CONTEXT.md" "AGENT_CONTEXT.md 存在"
check_file "docs/DEVELOPMENT.md" "DEVELOPMENT.md 存在"
check_file "docs/knowledge-base-index.yaml" "知识库索引存在"
echo ""

# 2. 检查设计文档目录
echo "2. 检查设计文档目录..."
check_directory "docs/design" "设计文档目录存在"
check_directory "docs/design/architecture" "架构设计目录存在"
check_directory "docs/design/features" "功能设计目录存在"
check_directory "docs/design/database" "数据库设计目录存在"
check_directory "docs/design/api" "接口设计目录存在"
check_directory "docs/design/implementation" "实施设计目录存在"
check_directory "docs/design/operations" "运维设计目录存在"
echo ""

# 3. 检查知识库文档
echo "3. 检查知识库文档..."
check_directory "docs/developer/design/code-knowledge-base" "代码知识库目录存在"
check_file "docs/developer/architecture/overall-architecture.md" "整体架构文档存在"
echo ""

# 4. 检查 Skill 目录
echo "4. 检查 Skill 目录..."
check_directory ".opencode/skills" "Skill 目录存在"
check_file ".opencode/skills/new-module.md" "新增模块 Skill 存在"
check_file ".opencode/skills/new-feature.md" "新功能 Skill 存在"
check_file ".opencode/skills/fix-bug.md" "修复 Bug Skill 存在"
echo ""

# 5. 检查源代码目录
echo "5. 检查源代码目录..."
check_directory "lib" "源代码目录存在"
check_directory "lib/models" "数据模型目录存在"
check_directory "lib/providers" "状态管理目录存在"
check_directory "lib/services" "服务层目录存在"
check_directory "lib/views" "页面目录存在"
check_directory "lib/components" "公共组件目录存在"
check_directory "lib/widgets" "业务组件目录存在"
check_directory "lib/theme" "主题目录存在"
check_directory "lib/utils" "工具类目录存在"
echo ""

# 6. 检查插件目录
echo "6. 检查插件目录..."
check_directory "plugs" "插件目录存在"
check_directory "plugs/omni_player" "OmniPlayer 插件存在"
check_directory "plugs/tdesign_flutter" "TDesign 插件存在"
echo ""

# 7. 检查 Supabase 目录
echo "7. 检查 Supabase 目录..."
check_directory "supabase" "Supabase 目录存在"
check_directory "supabase/functions" "Edge Functions 目录存在"
check_directory "supabase/migrations" "数据库迁移目录存在"
echo ""

# 8. 检查文档版本
echo "8. 检查文档版本..."
if [ -f "AGENTS.md" ]; then
    VERSION=$(grep -o "V[0-9]\+\.[0-9]\+" AGENTS.md | head -1)
    if [ -n "$VERSION" ]; then
        echo -e "${GREEN}✓${NC} AGENTS.md 版本: $VERSION"
    else
        echo -e "${YELLOW}!${NC} AGENTS.md 未找到版本信息"
        WARNINGS=$((WARNINGS + 1))
    fi
fi
echo ""

# 9. 检查文档与代码一致性
echo "9. 检查文档与代码一致性..."

# 检查 AGENTS.md 中的目录结构是否与实际一致
if [ -f "AGENTS.md" ]; then
    # 检查 lib/ 目录
    if [ -d "lib" ]; then
        echo -e "${GREEN}✓${NC} lib/ 目录存在"
    else
        echo -e "${RED}✗${NC} lib/ 目录不存在"
        ERRORS=$((ERRORS + 1))
    fi
    
    # 检查 plugs/ 目录
    if [ -d "plugs" ]; then
        echo -e "${GREEN}✓${NC} plugs/ 目录存在"
    else
        echo -e "${RED}✗${NC} plugs/ 目录不存在"
        ERRORS=$((ERRORS + 1))
    fi
    
    # 检查 supabase/ 目录
    if [ -d "supabase" ]; then
        echo -e "${GREEN}✓${NC} supabase/ 目录存在"
    else
        echo -e "${RED}✗${NC} supabase/ 目录不存在"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# 10. 检查文档更新时间
echo "10. 检查文档更新时间..."
if [ -f "AGENTS.md" ]; then
    MOD_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" AGENTS.md)
    echo -e "${GREEN}✓${NC} AGENTS.md 最后修改: $MOD_TIME"
fi
if [ -f "项目全局规则.md" ]; then
    MOD_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" 项目全局规则.md)
    echo -e "${GREEN}✓${NC} 项目全局规则.md 最后修改: $MOD_TIME"
fi
echo ""

# 总结
echo "=== 检查完成 ==="
echo ""
echo "总结:"
echo -e "  ${RED}错误: $ERRORS${NC}"
echo -e "  ${YELLOW}警告: $WARNINGS${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有检查通过！${NC}"
    exit 0
else
    echo -e "${RED}✗ 存在错误，请检查上述输出${NC}"
    exit 1
fi
