# 阶段三：茶园知识库导入与解析验收

## 阶段目标

本阶段目标是把甲方提供的茶园业务资料导入 RAGFlow，完成知识库创建、文档上传、解析切片、向量化和索引入库，形成可用于后续问答验证的茶业务知识底座。

## 账号与知识库

- 统一测试账号：`test@qq.com`
- 测试密码：`123`
- RAGFlow 访问地址：`http://127.0.0.1:8095`
- 知识库名称：`茶`
- 知识库 ID：`02c5a15a623711f194775f43a63146ec`
- 解析方式：`naive`，对应页面中的 `General / 通用`
- Embedding 模型：`bge-m3:latest@Ollama`
- Chat 模型：`deepseek-r1:70b@Ollama`

## 甲方数据

本阶段导入三份甲方茶业务 Excel 资料：

| 文件名 | 文件大小 | 业务含义 |
| --- | ---: | --- |
| 茶文化与茶健康.xlsx | 1288773 bytes | 茶健康、茶文化和科普类资料 |
| 茶文化学.xlsx | 144334 bytes | 茶文化基础知识资料 |
| 茶树栽培与发展历史问答.xlsx | 462981 bytes | 茶树栽培、发展历史、问答类资料 |

## Open WebUI 接管前后的模型调用差异

项目最初按直连 Ollama 的方式配置：

```yaml
factory: Ollama
base_url: http://153.101.206.98:50028
api_key: empty
```

该模式要求 `153.101.206.98:50028` 直接暴露 Ollama API，例如 `/api/tags` 返回模型列表。

后续模型服务器加入 Open WebUI 管理界面后，外网 NAT 仍然把 `153.101.206.98:50028` 映射到内网 `192.168.30.28:8080`，但内网 `8080` 已经由 Open WebUI 占用。因此直接访问 `http://153.101.206.98:50028` 时返回的是 Open WebUI 前端页面，不再是 Ollama API。

实际排查结果：

| 地址 | 结果 | 说明 |
| --- | --- | --- |
| `http://153.101.206.98:50028/api/tags` | 返回 Open WebUI HTML | 不是 Ollama API |
| `http://153.101.206.98:50028/ollama/api/tags` | 未带 token 时返回 401 | Open WebUI 代理需要认证 |
| `http://153.101.206.98:50028/ollama/api/tags` | 带 Bearer token 后返回模型列表 | Open WebUI Ollama 代理可用 |

最终配置改为通过 Open WebUI 的 Ollama 代理访问模型：

```yaml
factory: Ollama
base_url: http://153.101.206.98:50028/ollama
api_key: ${OPENWEBUI_API_KEY:-empty}
```

说明：

- Open WebUI 页面入口仍然是 `http://153.101.206.98:50028`。
- RAGFlow 调用 Ollama 的 API 入口必须使用 `http://153.101.206.98:50028/ollama`。
- API Key 使用 Open WebUI 生成的 Bearer Token。
- Token 只写入运行时配置或环境变量，不写入 Git 仓库文档。

## 本阶段代码与配置修复

本阶段补充了两处工程修复：

1. `docker/service_conf.yaml.template`
   - 将默认 Ollama base URL 从 `http://153.101.206.98:50028` 改为 `http://153.101.206.98:50028/ollama`。
   - 将默认 API Key 改为环境变量占位 `${OPENWEBUI_API_KEY:-empty}`，避免密钥进入代码仓库。

2. `api/db/services/knowledgebase_service.py`
   - 修复新建知识库时 `embd_id` 为空的问题。
   - 如果前端或 API 没有传 `embd_id`，或传入空值，则自动继承当前租户的默认 embedding 模型。

对应提交：

```text
94d664a fix: configure openwebui ollama proxy defaults
```

## 解析过程中的问题与处理

### 问题一：Open WebUI 接管后 401 Unauthorized

现象：

```text
Fail to bind embedding model: {"detail":"401 Unauthorized"} (status code: 401)
```

原因：

- RAGFlow 仍按无认证 Ollama 直连方式访问 `http://153.101.206.98:50028`。
- 该端口已经映射到 Open WebUI，Ollama 代理路径需要 Bearer Token。

处理：

- Open WebUI 管理端确认本地 Ollama 连接正常。
- RAGFlow 改为 `http://153.101.206.98:50028/ollama`。
- 为测试账号补齐 `TenantLLM` 中的 `deepseek-r1:70b` 和 `bge-m3:latest` 授权记录。

### 问题二：创建 Dataset 时 embedding 模型下拉为空

现象：

- `test@qq.com` 创建 Dataset 时找不到 embedding 模型记录。

原因：

- `tenant` 表中有默认 `embd_id=bge-m3:latest@Ollama`。
- 但 `tenant_llm` 表中没有该账号的实际模型授权记录。
- 创建知识库的后端逻辑原本也没有兜底继承 `tenant.embd_id`。

处理：

- 为 `test@qq.com` 补齐运行时模型授权记录。
- 代码层补充 `embd_id` 默认继承逻辑，避免后续新账号或新知识库再次出现空 embedding。

### 问题三：Q&A 解析时出现 NaN embedding

现象：

```text
Extract pairs: 701.
Generate 701 chunks
Generate embedding error: {"detail":"failed to encode response: json: unsupported value: NaN"}
```

原因判断：

- Q&A 模式从 Excel 中抽取了大量问答对。
- 部分行可能存在空值、异常字符、合并单元格或非标准问答结构。
- Embedding 服务返回了包含 NaN 的向量，导致 Open WebUI/Ollama JSON 响应编码失败。

处理：

- 暂不把 Q&A 精细切分作为阶段三必选项。
- 将该文件改用 `General / 通用` 方式解析，优先保证资料稳定入库。
- Q&A 结构化清洗留到后续优化阶段处理。

## 最终验收结果

知识库 `茶` 已完成三份文档解析、embedding 和索引入库：

| 文件名 | 解析状态 | Chunk 数 | Token 数 | 文件大小 | 验收日志 |
| --- | --- | ---: | ---: | ---: | --- |
| 茶文化与茶健康.xlsx | 完成 | 220 | 28288 | 1288773 | `Embedding chunks`、`Indexing done`、`Task done` |
| 茶文化学.xlsx | 完成 | 121 | 15616 | 144334 | `Embedding chunks`、`Indexing done`、`Task done` |
| 茶树栽培与发展历史问答.xlsx | 完成 | 308 | 39552 | 462981 | `Embedding chunks`、`Indexing done`、`Task done` |

汇总：

```text
知识库文档数：3
总 Chunk 数：649
总 Token 数：83456
三份文档 run 状态：3
三份文档 progress：1.0
```

验收判定：

- 三份甲方 Excel 已上传。
- 三份文档均已完成解析。
- 三份文档均已完成 embedding。
- 三份文档均已完成索引写入。
- 阶段三目标达成，可进入阶段四：茶园业务问答应用与检索效果验证。

## 后续阶段建议

阶段四建议重点完成：

1. 创建面向茶园老板的业务问答应用。
2. 设计茶树栽培、茶文化、茶健康三类测试问题。
3. 验证答案是否引用知识库内容，是否能命中文档片段。
4. 梳理召回不足、回答不准、格式不适合业务用户的问题。
5. 形成可写入简历的“数据导入、知识库构建、模型接入、RAG 问答验收”闭环。
