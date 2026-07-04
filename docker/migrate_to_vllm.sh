#!/usr/bin/env bash
# =============================================================================
# RAGFlow 模型迁移脚本: Ollama -> VLLM (OpenAI 兼容)
# 用法: bash migrate_to_vllm.sh
# 放到 docker/ 目录下运行
# =============================================================================

set -e

# Chat 模型: OpenAI_APIChat 将 base_url 原样传给 OpenAI 客户端, 需要包含 /v1
CHAT_API_BASE="http://221.230.21.203:50028/v1"
# Embedding 模型: OpenAI_APIEmbed 构造函数会自动 urljoin(base_url, "v1"), 不能带 /v1
EMBED_API_BASE="http://221.230.21.203:50028"
NEW_FACTORY="VLLM"
CHAT_MODEL="qwen3"
EMBED_MODEL="bge-m3"
API_KEY="sk-ragflow-local"
MYSQL_USER="root"
MYSQL_PASSWORD="infini_rag_flow"
MYSQL_DB="rag_flow"

# -----------------------------------------------------------------------------
# 颜色输出
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# 查找 MySQL 连接方式
# -----------------------------------------------------------------------------
find_mysql_cmd() {
    # 方式1: 宿主机有 mysql 客户端，通过暴露端口连接
    if command -v mysql &> /dev/null; then
        if mysql -h 127.0.0.1 -P 5455 -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" &> /dev/null; then
            echo "mysql -h 127.0.0.1 -P 5455 -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DB}"
            return
        fi
    fi

    # 方式2: 通过 docker exec 进 mysql 容器
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
    error "无法连接到 MySQL，请检查:"
    echo "  1. 容器是否在运行: docker ps | grep mysql"
    echo "  2. 端口 5455 是否暴露: netstat -tlnp | grep 5455"
    echo "  3. 或者手动执行脚本中的 SQL"
    exit 1
fi

info "使用连接方式: ${MYSQL_CMD}"

# -----------------------------------------------------------------------------
# 预检查
# -----------------------------------------------------------------------------
info "========== 预检查 =========="

# 检查 VLLM 工厂是否存在
FACTORY_COUNT=$(eval "${MYSQL_CMD} -N -e \"SELECT COUNT(*) FROM llm_factories WHERE name='${NEW_FACTORY}';\" 2>/dev/null")
if [ "$FACTORY_COUNT" -eq 0 ]; then
    error "llm_factories 表中没有 ${NEW_FACTORY} 工厂，请先确认 init_llm_factory 是否执行过"
    exit 1
fi
info "VLLM 工厂已存在: OK"

# 列出当前租户
info "当前租户及默认模型:"
eval "${MYSQL_CMD} -e \"SELECT id, name, llm_id, embd_id FROM tenant;\""

echo
info "========== 开始迁移 =========="

# -----------------------------------------------------------------------------
# 步骤0: 清理之前可能残留的错误 VLLM 数据
# -----------------------------------------------------------------------------
info "步骤0: 清理旧的 VLLM 配置 ..."
DELETED=$(eval "${MYSQL_CMD} -N -e \"SELECT COUNT(*) FROM tenant_llm WHERE llm_factory='${NEW_FACTORY}';\" 2>/dev/null")
if [ "$DELETED" -gt 0 ]; then
    warn "发现 ${DELETED} 条旧的 VLLM 记录，正在删除..."
    eval "${MYSQL_CMD} -e \"DELETE FROM tenant_llm WHERE llm_factory='${NEW_FACTORY}';\""
    info "已清理"
else
    info "无旧数据，跳过"
fi

# -----------------------------------------------------------------------------
# 步骤1: 为每个租户添加 Chat 模型
# -----------------------------------------------------------------------------
info "步骤1: 添加 Chat 模型 qwen3___VLLM ..."
eval "${MYSQL_CMD}" <<SQL
INSERT INTO tenant_llm (tenant_id, llm_factory, model_type, llm_name, api_base, api_key, max_tokens, used_tokens, status)
SELECT t.id, '${NEW_FACTORY}', 'chat', '${CHAT_MODEL}___${NEW_FACTORY}', '${CHAT_API_BASE}', '${API_KEY}', 8192, 0, '1'
FROM tenant t
WHERE NOT EXISTS (
    SELECT 1 FROM tenant_llm tl
    WHERE tl.tenant_id = t.id
      AND tl.llm_factory = '${NEW_FACTORY}'
      AND tl.llm_name = '${CHAT_MODEL}___${NEW_FACTORY}'
);
SQL
info "完成"

# -----------------------------------------------------------------------------
# 步骤2: 为每个租户添加 Embedding 模型
# -----------------------------------------------------------------------------
info "步骤2: 添加 Embedding 模型 bge-m3___VLLM ..."
eval "${MYSQL_CMD}" <<SQL
INSERT INTO tenant_llm (tenant_id, llm_factory, model_type, llm_name, api_base, api_key, max_tokens, used_tokens, status)
SELECT t.id, '${NEW_FACTORY}', 'embedding', '${EMBED_MODEL}___${NEW_FACTORY}', '${EMBED_API_BASE}', '${API_KEY}', 8192, 0, '1'
FROM tenant t
WHERE NOT EXISTS (
    SELECT 1 FROM tenant_llm tl
    WHERE tl.tenant_id = t.id
      AND tl.llm_factory = '${NEW_FACTORY}'
      AND tl.llm_name = '${EMBED_MODEL}___${NEW_FACTORY}'
);
SQL
info "完成"

# -----------------------------------------------------------------------------
# 步骤3: 切换所有租户的默认模型
# -----------------------------------------------------------------------------
info "步骤3: 更新租户默认模型 ..."
CHANGED_COUNT=$(eval "${MYSQL_CMD} -N -e \"SELECT COUNT(*) FROM tenant WHERE llm_id NOT LIKE '%${CHAT_MODEL}@${NEW_FACTORY}%' OR embd_id NOT LIKE '%${EMBED_MODEL}@${NEW_FACTORY}%';\"")
info "需要更新的租户数: ${CHANGED_COUNT}"

eval "${MYSQL_CMD}" <<SQL
UPDATE tenant
SET llm_id  = '${CHAT_MODEL}@${NEW_FACTORY}',
    embd_id = '${EMBED_MODEL}@${NEW_FACTORY}'
WHERE llm_id NOT LIKE '%${CHAT_MODEL}@${NEW_FACTORY}%'
   OR embd_id NOT LIKE '%${EMBED_MODEL}@${NEW_FACTORY}%';
SQL
info "完成"

# -----------------------------------------------------------------------------
# 验证
# -----------------------------------------------------------------------------
info "========== 验证结果 =========="
info "各租户默认模型:"
eval "${MYSQL_CMD} -e \"SELECT id, name, llm_id, embd_id FROM tenant;\""

info "各租户 VLLM 模型配置:"
eval "${MYSQL_CMD} -e \"SELECT tenant_id, llm_factory, model_type, llm_name, api_base, status FROM tenant_llm WHERE llm_factory='${NEW_FACTORY}' ORDER BY tenant_id, model_type;\""

echo
info "========== 迁移完成 =========="
info "请执行以下命令重启 RAGFlow:"
info "  cd $(pwd) && docker compose restart ragflow-cpu"
info "  或: docker compose restart ragflow-gpu"
echo
info "如果 VLLM 服务不可用，可在 Web UI 的 模型供应商 页面切回旧模型。"
