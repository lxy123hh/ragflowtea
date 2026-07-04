#!/usr/bin/env bash
# =============================================================================
# RAGFlow Tea: 为已有租户添加 qwen-vl 图片识别模型
# 用法: bash add_qwen_vl.sh
# 放到 docker/ 目录下运行
# =============================================================================

set -e

IMAGE2TEXT_API_BASE="http://221.230.21.203:50028"
FACTORY="VLLM"
MODEL_NAME="qwen-vl"
API_KEY="sk-ragflow-local"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-infini_rag_flow}"
MYSQL_DB="${MYSQL_DB:-rag_flow}"
MYSQL_PORT="${MYSQL_PORT:-5455}"

# -----------------------------------------------------------------------------
# 颜色
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# 查找 MySQL 连接
# -----------------------------------------------------------------------------
find_mysql_cmd() {
    if command -v mysql &> /dev/null; then
        if mysql -h 127.0.0.1 -P "${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" &> /dev/null; then
            echo "mysql -h 127.0.0.1 -P ${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DB}"
            return
        fi
    fi

    local MYSQL_CONTAINER
    MYSQL_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i mysql | head -1)
    if [ -n "$MYSQL_CONTAINER" ]; then
        echo "docker exec -i ${MYSQL_CONTAINER} mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DB}"
        return
    fi

    echo ""
}

MYSQL_CMD=$(find_mysql_cmd)

if [ -z "$MYSQL_CMD" ]; then
    error "无法连接到 MySQL"
    echo "  1. 检查端口 ${MYSQL_PORT}: netstat -tlnp | grep ${MYSQL_PORT}"
    echo "  2. 检查容器: docker ps | grep mysql"
    exit 1
fi

info "MySQL 连接: ${MYSQL_CMD}"

# -----------------------------------------------------------------------------
# 预检查
# -----------------------------------------------------------------------------
info "========== 预检查 =========="

FACTORY_COUNT=$(eval "${MYSQL_CMD} -N -e \"SELECT COUNT(*) FROM llm_factories WHERE name='${FACTORY}';\" 2>/dev/null")
if [ "$FACTORY_COUNT" -eq 0 ]; then
    error "llm_factories 表中没有 ${FACTORY} 工厂，请先运行 migrate_to_vllm.sh"
    exit 1
fi
info "VLLM 工厂存在: OK"

# -----------------------------------------------------------------------------
# 步骤1: 为每个租户添加 image2text 模型
# -----------------------------------------------------------------------------
info "步骤1: 添加 image2text 模型 qwen-vl___VLLM ..."

eval "${MYSQL_CMD}" <<SQL
INSERT INTO tenant_llm (tenant_id, llm_factory, model_type, llm_name, api_base, api_key, max_tokens, used_tokens, status)
SELECT t.id, '${FACTORY}', 'image2text', '${MODEL_NAME}___${FACTORY}', '${IMAGE2TEXT_API_BASE}', '${API_KEY}', 8192, 0, '1'
FROM tenant t
WHERE NOT EXISTS (
    SELECT 1 FROM tenant_llm tl
    WHERE tl.tenant_id = t.id
      AND tl.llm_factory = '${FACTORY}'
      AND tl.llm_name = '${MODEL_NAME}___${FACTORY}'
);
SQL
info "完成"

# -----------------------------------------------------------------------------
# 步骤2: 切换所有租户的 img2txt_id
# -----------------------------------------------------------------------------
info "步骤2: 更新 tenant.img2txt_id ..."

CHANGED=$(eval "${MYSQL_CMD} -N -e \"SELECT COUNT(*) FROM tenant WHERE img2txt_id IS NULL OR img2txt_id = '' OR img2txt_id <> '${MODEL_NAME}@${FACTORY}';\"")
info "需要更新的租户: ${CHANGED}"

eval "${MYSQL_CMD}" <<SQL
UPDATE tenant
SET img2txt_id = '${MODEL_NAME}@${FACTORY}'
WHERE img2txt_id IS NULL
   OR img2txt_id = ''
   OR img2txt_id <> '${MODEL_NAME}@${FACTORY}';
SQL
info "完成"

# -----------------------------------------------------------------------------
# 验证
# -----------------------------------------------------------------------------
info "========== 验证 =========="
info "租户 img2txt_id:"
eval "${MYSQL_CMD} -e \"SELECT id, name, img2txt_id FROM tenant;\""

info "image2text 模型记录:"
eval "${MYSQL_CMD} -e \"SELECT tenant_id, llm_factory, model_type, llm_name, api_base, status FROM tenant_llm WHERE model_type='image2text';\""

echo
info "========== 完成 =========="
