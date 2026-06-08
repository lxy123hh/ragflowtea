# 茶园业务知识库 AI 问答助手最终交付文档

## 项目定位

本项目是在 RAGFlow 开源框架基础上，为茶园老板落地的本地化 AI 知识库问答系统。甲方提供茶树栽培、茶文化、茶健康相关 Excel 资料，系统将这些资料构建为可检索知识库，并通过本地部署的大模型完成面向业务场景的检索增强问答。

项目不是简单“上传资料使用框架”，而是完成了从环境部署、模型接入、知识库构建、业务问答、问题排查、质量优化、指标验收到简历材料沉淀的完整闭环。

## 业务场景

目标用户：茶园老板、茶园工作人员、需要向客户解释茶相关知识的经营者。

核心问题：

- 客户问茶叶健康价值时，老板需要快速给出通俗解释。
- 茶园管理中遇到土壤、水分、栽培问题时，需要从资料中快速查找依据。
- 做茶文化介绍或产品讲解时，需要把历史、文化和健康资料整合成可表达内容。

最终交付目标：

- 把甲方茶资料变成可问答知识库。
- 用本地大模型保护资料和问答数据。
- 形成可演示、可复盘、可写入简历的 AI 应用项目。

## 技术架构

```text
用户 / 茶园老板
  -> RAGFlow Web / API
  -> Knowledge Base Retrieval
  -> Elasticsearch 向量与文本检索
  -> BGE-M3 Embedding
  -> DeepSeek-R1 70B Chat
  -> Open WebUI Ollama Proxy
  -> 本地 Ollama 模型服务
```

基础服务：

| 模块 | 作用 |
| --- | --- |
| RAGFlow | 知识库管理、文档解析、检索增强问答、对话应用 |
| Docker Compose | 本地服务编排和一键启动 |
| MySQL | RAGFlow 元数据存储 |
| Elasticsearch | 文本检索和向量检索 |
| MinIO | 文件对象存储 |
| Redis | 缓存和任务队列 |
| Ollama | 本地模型推理服务 |
| Open WebUI | 本地模型统一管理和 API 代理 |
| DeepSeek-R1 70B | Chat 生成模型 |
| BGE-M3 | Embedding 向量模型 |
| 茶园业务工具服务 | 茶叶推荐、销售话术、价格库存和客户问题分流 |

## 本地启动

进入 Docker 目录：

```powershell
cd D:\study\project\tea\ragflowtea\docker
```

启动服务：

```powershell
docker compose -f docker-compose.yml up -d
```

查看服务状态：

```powershell
docker compose -f docker-compose.yml ps
```

访问地址：

```text
RAGFlow Web: http://127.0.0.1:8095
RAGFlow API: http://127.0.0.1:9380
```

统一测试账号：

```text
账号：test@qq.com
密码：123
```

## 模型接入说明

当前模型服务由 Open WebUI 接管本地 Ollama 模型。

关键区别：

| 场景 | 调用方式 |
| --- | --- |
| Open WebUI 页面 | `http://153.101.206.98:50028` |
| Ollama API 代理 | `http://153.101.206.98:50028/ollama` |
| RAGFlow Chat / Embedding | 必须配置到 `/ollama` 路径 |

原因：

- 外网 `153.101.206.98:50028` 通过 NAT 映射到内网 Open WebUI 的 `8080` 端口。
- 根路径返回 Open WebUI 页面，不是 Ollama API。
- RAGFlow 要调用模型，需要走 Open WebUI 暴露的 Ollama 兼容代理 `/ollama`。

模型配置：

| 类型 | 模型 |
| --- | --- |
| Chat | `deepseek-r1:70b@Ollama` |
| Embedding | `bge-m3:latest@Ollama` |

安全要求：

- Open WebUI API Key 只能放在运行时配置或环境变量。
- 不允许写入 Git 仓库和 Markdown 文档。

## 知识库建设

甲方数据：

| 文件 | 解析结果 |
| --- | ---: |
| 茶文化与茶健康.xlsx | 220 chunks，28,288 tokens |
| 茶文化学.xlsx | 121 chunks，15,616 tokens |
| 茶树栽培与发展历史问答.xlsx | 308 chunks，39,552 tokens |
| 合计 | 649 chunks，83,456 tokens |

知识库信息：

```text
知识库名称：茶
知识库 ID：02c5a15a623711f194775f43a63146ec
Embedding：bge-m3:latest@Ollama
```

重要处理记录：

- Q&A 解析方式曾触发 `json: unsupported value: NaN`。
- 改用 General 解析后稳定入库。
- 后续如要继续优化，可清洗 Excel 表格后建立专门 Q&A 知识库。

## 问答应用

正式助手：

```text
名称：茶园业务问答助手
Dialog ID：22d7a6b4624611f194785f43a63146ec
```

优化版助手：

```text
名称：茶园业务问答助手-优化版
Dialog ID：0537154e625611f1b6324b1f5b3b5659
```

优化版配置：

| 参数 | 值 |
| --- | ---: |
| `top_n` | 4 |
| `top_k` | 512 |
| `similarity_threshold` | 0.1 |
| `vector_similarity_weight` | 0.3 |
| `max_tokens` | 500 |
| `temperature` | 0.1 |
| `top_p` | 0.7 |

提示词约束：

- 只输出最终业务回答。
- 不输出分析过程、检索过程或系统调试信息。
- 回答从 `1.` 开始。
- 使用 3 到 5 条要点。
- 没有资料依据时说明“资料中未明确提到”。
- 禁止输出 `<think>`、`</think>`、`知识库`、`检索` 等不适合客户可见的词。

## Agent 工具调用能力

为补齐“茶叶知识问答 + 业务动作”的 Agent 能力，项目新增独立 HTTP 工具服务：

```text
tools/tea_agent_tools/tea_business_tool_server.py
```

启动方式：

```powershell
python tools\tea_agent_tools\tea_business_tool_server.py --host 127.0.0.1 --port 18088
```

工具接口：

| 接口 | 能力 |
| --- | --- |
| `POST /tools/recommend_tea` | 根据预算、口味、用途、人群、是否送礼、是否新手推荐茶品 |
| `POST /tools/generate_sales_script` | 生成销售人员可直接使用的话术 |
| `POST /tools/query_inventory` | 查询演示用价格和库存 |
| `POST /tools/classify_question` | 判断客户问题类型和建议处理方式 |
| `POST /agent/handle_customer` | 根据客户问题自动分流并调用业务工具 |

验收结果：

| 指标 | 结果 |
| --- | ---: |
| 业务工具接口 | 4 个 |
| Agent 路由接口 | 1 个 |
| 单元测试 | 5/5 通过 |
| HTTP 验收接口 | 3 个通过 |
| 本地规则工具计算耗时 | 低于 1ms |

该能力用于处理普通 RAG 不适合自由生成的业务动作，例如价格库存查询、送礼推荐和销售话术生成。RAGFlow Agent/Workflow 可以通过 `http://127.0.0.1:18088/openapi.json` 接入这些 HTTP 工具。

## 关键问题与修复

### 1. Docker 无法连接

现象：

```text
open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified
```

结论：

- Docker Desktop Linux Engine 未启动。
- 启动 Docker Desktop / WSL / Hyper-V 后恢复。

### 2. Docker 镜像拉取超时

现象：

```text
TLS handshake timeout
```

结论：

- 网络拉取 Docker Hub 镜像超时。
- 重试或配置镜像加速后可继续。

### 3. Embedding 模型在创建知识库时不可选

原因：

- 用户默认模型配置未正确写入 `TenantLLM`。
- 创建 Dataset 时没有默认 `embd_id` 可用。

处理：

- 为 `test@qq.com` 配置 `bge-m3:latest@Ollama`。
- 修复知识库创建时 `embd_id` 为空的默认回填逻辑。

### 4. Open WebUI 代理导致 Chat 调用失败

现象：

```text
INVALID_REQUEST - litellm.APIConnectionError: Ollama_chatException
Input should be a valid dictionary
```

排查：

- 手动调用 `POST /ollama/api/chat` 成功。
- Embedding 接口正常。
- 问题集中在 RAGFlow 通过 LiteLLM 的 Ollama Chat provider 调用 Open WebUI 代理时的兼容性。

处理：

- 新增原生 `OllamaChat` 适配。
- 使用 `ollama.AsyncClient` 直接调用 Open WebUI `/ollama` 代理。
- 支持 Bearer Header。
- 将 RAGFlow `max_tokens` 转换为 Ollama `num_predict`。

### 5. Reasoning 模型输出 `<think>`

原因：

- `deepseek-r1:70b` 是 reasoning 模型，可能输出推理过程。

处理：

- 在 `OllamaChat` 返回结果时清洗 `<think>` 内容。
- 通过提示词限制只输出最终业务答案。

结果：

- 三类测试问题中 `<think>` 和调试词命中为 0。

## 验收指标

知识库指标：

| 指标 | 数值 |
| --- | ---: |
| 甲方文件数 | 3 |
| 知识片段数 | 649 |
| Token 数 | 83,456 |
| 核心业务测试问题 | 3 类 |
| 业务工具接口 | 4 个 |
| Agent 路由接口 | 1 个 |
| 工具单元测试 | 5/5 通过 |

优化指标：

| 指标 | 优化前 | 优化后 | 变化 |
| --- | ---: | ---: | ---: |
| `top_n` | 6 | 4 | 减少 33.33% |
| `top_k` | 1024 | 512 | 减少 50.00% |
| `max_tokens` | 600 | 500 | 减少 16.67% |
| 平均端到端耗时 | 236.40 秒 | 206.90 秒 | 降低 12.48% |
| 格式合规 | 未强约束 | 3/3 | 100% |
| 禁用词命中 | 有风险 | 0 | 已消除 |

注意：

- 激进压缩配置曾达到平均提速 23.86%，但会暴露 reasoning 内容，因此没有作为最终生产配置。
- 最终配置选择质量优先，在保证业务可展示的前提下获得 12.48% 平均耗时降低。

## 简历推荐写法

项目名称：

```text
茶园业务知识库 AI 问答助手
```

项目描述：

```text
基于 RAGFlow 二次落地茶园业务知识库问答系统，使用 Docker Compose 部署 MySQL、Elasticsearch、MinIO、Redis 与 RAGFlow 服务，接入 Open WebUI 管理的本地 Ollama 模型，Chat 使用 DeepSeek-R1 70B，Embedding 使用 BGE-M3。将甲方提供的茶树栽培、茶文化、茶健康 Excel 资料构建为知识库，并围绕茶园老板的客户答疑、栽培管理和茶文化介绍场景完成检索增强问答、模型代理兼容修复、提示词优化和阶段验收。
```

技术栈：

```text
RAGFlow、Docker Compose、MySQL、Elasticsearch、MinIO、Redis、Ollama、Open WebUI、DeepSeek-R1 70B、BGE-M3、RAG、Embedding、向量检索、提示词工程、模型代理适配、知识库解析、问答质量评测
```

项目亮点：

```text
- 完成 RAGFlow 茶园知识库 AI 助手本地化部署，接入 Open WebUI 管理的本地 Ollama 模型，修复 RAGFlow 调用 Open WebUI Ollama Chat 代理不兼容问题。
- 导入并解析甲方 3 份茶业务 Excel 资料，构建 649 个知识片段、83,456 tokens 的茶园业务知识库。
- 围绕茶健康、茶树栽培、茶文化 3 类核心问题完成检索与问答验收，回答格式合规率达到 3/3，调试词和 reasoning 标签命中为 0。
- 通过 top_n、top_k、max_tokens 与提示词优化，将检索上下文减少 33.33%、候选上限减少 50.00%、生成上限减少 16.67%，最终三类问题平均端到端耗时由 236.40 秒降至 206.90 秒，降低 12.48%。
- 新增茶园业务 HTTP 工具服务，提供茶叶推荐、销售话术、价格库存查询和客户问题分流 4 类工具能力，完成 5 个单元测试和 3 个 HTTP 接口验收。
```

## 后续可扩展方向

下一步可以继续做：

- 接入 Langfuse 或 LangSmith 记录每次问答的 trace、耗时、token、命中文档和人工评分。
- 清洗 Excel 数据，拆分“茶文化”“茶健康”“栽培问答”多个知识库。
- 增加茶园客户服务工作流，例如根据客户问题自动生成销售话术。
- 增加管理端评测集，固定 20 到 50 个问题定期回归测试。
- 增加 Agent 工具调用，例如茶园管理日历、施肥计划、客户咨询记录。
