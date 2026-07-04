#!/bin/bash

# =============================================================================
# Tea 项目一键配置脚本: 从原版 RAGFlow 切换到 VLLM 模型
# 用法: bash setup_tea.sh [apply|restore|help]
# 放到 docker/ 目录下运行
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# 配置变量
# -----------------------------------------------------------------------------
TEMPLATE_FILE="service_conf.yaml.template"
BACKUP_FILE="${TEMPLATE_FILE}.tea_backup"
CHAT_API_BASE="http://221.230.21.203:50028/v1"
EMBED_API_BASE="http://221.230.21.203:50028"
IMAGE2TEXT_API_BASE="http://221.230.21.203:50028"
NEW_FACTORY="VLLM"
CHAT_MODEL="qwen3"
EMBED_MODEL="bge-m3"
IMAGE2TEXT_MODEL="qwen-vl"
API_KEY="sk-ragflow-local"

# -----------------------------------------------------------------------------
# 颜色输出
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# -----------------------------------------------------------------------------
# 帮助
# -----------------------------------------------------------------------------
show_help() {
    echo "Tea 项目 VLLM 一键配置工具"
    echo ""
    echo "用法:"
    echo "  bash setup_tea.sh [操作]"
    echo ""
    echo "操作:"
    echo "  apply     - 将 service_conf.yaml.template 切换为 VLLM 配置 (默认)"
    echo "  restore   - 恢复为 Tea 备份 (如果存在)"
    echo "  help      - 显示本帮助"
    echo ""
    echo "示例:"
    echo "  bash setup_tea.sh              # 应用 VLLM 配置"
    echo "  bash setup_tea.sh apply        # 同上"
    echo "  bash setup_tea.sh restore      # 恢复到修改前"
    echo ""
    echo "适用场景:"
    echo "  从原版 RAGFlow git clone 后, 运行本脚本一键切换到:"
    echo "    Chat:      ${CHAT_MODEL}"
    echo "    Embedding: ${EMBED_MODEL}"
    echo "    Image2Text: ${IMAGE2TEXT_MODEL}"
    echo "  所有模型通过 litellm 代理访问: ${EMBED_API_BASE}"
}

# -----------------------------------------------------------------------------
# 检查文件
# -----------------------------------------------------------------------------
check_files() {
    if [ ! -f "$TEMPLATE_FILE" ]; then
        error "找不到 ${TEMPLATE_FILE}, 请在 docker/ 目录下运行本脚本"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# 应用 VLLM 配置
# -----------------------------------------------------------------------------
apply_config() {
    check_files

    # 检查是否已经应用过
    if grep -q "factory: 'VLLM'" "$TEMPLATE_FILE" 2>/dev/null; then
        warn "${TEMPLATE_FILE} 已经是 VLLM 配置, 跳过"
        info "如需重新应用, 请先运行: bash setup_tea.sh restore"
        return
    fi

    # 备份原文件
    step "步骤 1/3: 备份原文件 → ${BACKUP_FILE}"
    cp "$TEMPLATE_FILE" "$BACKUP_FILE"
    info "已备份"

    # 替换 user_default_llm 段
    step "步骤 2/3: 写入 VLLM 模型配置 ..."

    python3 -c "
import re

with open('${TEMPLATE_FILE}', 'r') as f:
    content = f.read()

new_llm = '''user_default_llm:
  factory: 'VLLM'
  api_key: 'sk-ragflow-local'
  base_url: 'http://221.230.21.203:50028'
  default_models:
    chat_model:
      name: 'qwen3'
      base_url: 'http://221.230.21.203:50028/v1'
    embedding_model:
      name: 'bge-m3'
    rerank_model: ''
    asr_model: ''
    image2text_model: 'qwen-vl\''''

pattern = r'user_default_llm:\s*\n(?:  .*\n?)*'
content = re.sub(pattern, new_llm, content)

with open('${TEMPLATE_FILE}', 'w') as f:
    f.write(content)
" 2>/dev/null || {
        # Python 不可用时用 awk 回退
        warn "Python 不可用, 使用 awk 回退方案"
        awk '
        BEGIN { in_block=0; done=0 }
        /^user_default_llm:/ { in_block=1; if (!done) {
            print "user_default_llm:"
            print "  factory: '\''VLLM'\''"
            print "  api_key: '\''sk-ragflow-local'\''"
            print "  base_url: '\''http://221.230.21.203:50028'\''"
            print "  default_models:"
            print "    chat_model:"
            print "      name: '\''qwen3'\''"
            print "      base_url: '\''http://221.230.21.203:50028/v1'\''"
            print "    embedding_model:"
            print "      name: '\''bge-m3'\''"
            print "    rerank_model: '\'''\''"
            print "    asr_model: '\'''\''"
            print "    image2text_model: '\''qwen-vl'\''"
            done=1; next
        }}
        /^[a-z]/ && in_block { in_block=0 }
        !in_block
        ' "$BACKUP_FILE" > "$TEMPLATE_FILE"
    }

    info "配置已写入"

    # 检查模板语法
    step "步骤 3/3: 验证模板 ..."
    if grep -q "qwen3" "$TEMPLATE_FILE" && grep -q "bge-m3" "$TEMPLATE_FILE"; then
        info "模板验证通过"
    else
        warn "模板可能不完整, 请手动检查 ${TEMPLATE_FILE}"
    fi

    echo
    info "========== 配置完成 =========="
    info "接下来请执行:"
    info "  docker compose -f docker-compose.yml up -d"
    info ""
    info "容器启动后, 运行数据库迁移:"
    info "  bash migrate_to_vllm.sh"
    info ""
    info "如需恢复原配置:"
    info "  bash setup_tea.sh restore"
}

# -----------------------------------------------------------------------------
# 恢复原始配置
# -----------------------------------------------------------------------------
restore_config() {
    check_files

    if [ ! -f "$BACKUP_FILE" ]; then
        error "找不到备份文件 ${BACKUP_FILE}, 无法恢复"
        exit 1
    fi

    step "恢复原文件: ${BACKUP_FILE} → ${TEMPLATE_FILE}"
    cp "$BACKUP_FILE" "$TEMPLATE_FILE"
    rm "$BACKUP_FILE"
    info "已恢复, 备份文件已删除"
}

# -----------------------------------------------------------------------------
# 主入口
# -----------------------------------------------------------------------------
main() {
    local operation=${1:-apply}

    case "$operation" in
        apply|"")
            apply_config
            ;;
        restore)
            restore_config
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            error "无效操作: ${operation}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
