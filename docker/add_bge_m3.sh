#!/usr/bin/env bash
# =============================================================================
# RAGFlow Tea: 为已有租户添加 bge-m3 向量化模型 (VLLM)
# 用法: bash add_bge_m3.sh
# 放到 docker/ 目录下运行
# =============================================================================

set -e

EMBEDDING_API_BASE="http://221.230.21.203:50028"
FACTORY="VLLM"
MODEL_NAME="bge-m3"
API_KEY="sk-ragflow-local"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-infini_rag_flow}"
MYSQL_DB="${MYSQL_DB:-rag_flow}"
MYSQL_PORT="${MYSQL_PORT:-5455}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

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

run_sql() {
    eval "${MYSQL_CMD}" 2>/dev/null
}

MYSQL_CMD=$(find_mysql_cmd)

if [ -z "$MYSQL_CMD" ]; then
    error "无法连接到 MySQL"
    exit 1
fi

info "MySQL 连接: ${MYSQL_CMD}"

# -----------------------------------------------------------------------------
info "========== 预检查 =========="
FACTORY_COUNT=$(run_sql <<< "SELECT COUNT(*) FROM llm_factories WHERE name='${FACTORY}';")
if [ "$FACTORY_COUNT" -eq 0 ]; then
    error "llm_factories 表中没有 ${FACTORY} 工厂"
    exit 1
fi
info "VLLM 工厂存在: OK"

# -----------------------------------------------------------------------------
info "步骤1: 添加 embedding 模型 bge-m3___VLLM ..."
run_sql <<SQL
INSERT INTO tenant_llm (tenant_id, llm_factory, model_type, llm_name, api_base, api_key, max_tokens, used_tokens, status)
SELECT t.id, '${FACTORY}', 'embedding', '${MODEL_NAME}___${FACTORY}', '${EMBEDDING_API_BASE}', '${API_KEY}', 8192, 0, '1'
FROM tenant t
WHERE NOT EXISTS (
    SELECT 1 FROM tenant_llm tl
    WHERE tl.tenant_id = t.id
      AND tl.llm_factory = '${FACTORY}'
      AND tl.model_type = 'embedding'
      AND tl.llm_name = '${MODEL_NAME}___${FACTORY}'
);
SQL
info "完成"

# -----------------------------------------------------------------------------
info "步骤2: 更新 tenant.embd_id ..."
run_sql <<SQL
UPDATE tenant
SET embd_id = '${MODEL_NAME}@${FACTORY}'
WHERE embd_id IS NULL
   OR embd_id = ''
   OR embd_id <> '${MODEL_NAME}@${FACTORY}';
SQL
info "完成"

# -----------------------------------------------------------------------------
info "步骤3: 更新 knowledgebase.embd_id (Ollama → VLLM) ..."
run_sql <<SQL
UPDATE knowledgebase
SET embd_id = '${MODEL_NAME}@${FACTORY}'
WHERE embd_id IS NULL
   OR embd_id = ''
   OR embd_id LIKE '%Ollama%';
SQL
info "完成"

# -----------------------------------------------------------------------------
info "步骤4: 补充 VLLM 工厂 IMAGE2TEXT 标签 ..."
run_sql <<SQL
UPDATE llm_factories
SET tags = 'LLM,TEXT EMBEDDING,SPEECH2TEXT,MODERATION,IMAGE2TEXT'
WHERE name = '${FACTORY}'
  AND tags NOT LIKE '%IMAGE2TEXT%';
SQL
info "完成"

# -----------------------------------------------------------------------------
info "========== 验证 =========="
echo "--- 租户模型配置 ---"
run_sql <<< "SELECT id, name, llm_id, embd_id, img2txt_id FROM tenant;"

echo "--- 知识库 embedding ---"
run_sql <<< "SELECT id, name, embd_id FROM knowledgebase;"

echo "--- VLLM 工厂 tags ---"
run_sql <<< "SELECT name, tags FROM llm_factories WHERE name='${FACTORY}';"

echo "--- embedding 模型记录 ---"
run_sql <<< "SELECT tenant_id, llm_factory, model_type, llm_name, api_base FROM tenant_llm WHERE model_type='embedding';"

echo
info "========== 完成 =========="
