# 茶园业务知识库 AI 问答助手面试演示脚本

## 30 秒项目介绍

这个项目是我基于 RAGFlow 落地的茶园业务知识库 AI 问答助手。甲方提供了茶树栽培、茶文化、茶健康三类 Excel 资料，我将它们解析成 649 个知识片段、83,456 tokens 的知识库，并接入 Open WebUI 管理的本地 Ollama 模型，Chat 使用 DeepSeek-R1 70B，Embedding 使用 BGE-M3。项目中我完成了 Docker 本地部署、模型代理接入、知识库构建、问答应用配置、Open WebUI Ollama Chat 兼容性修复、回答质量优化，并补充了茶叶推荐、销售话术、价格库存和客户问题分流工具。

## 2 分钟技术讲解

可以按这个顺序讲：

1. 业务背景

   茶园老板需要把现有资料变成能直接问答的工具，用于客户答疑、栽培管理和茶文化介绍。

2. 架构设计

   RAGFlow 负责知识库、文档解析、检索和对话；MySQL 存元数据；Elasticsearch 做检索；MinIO 存文件；Redis 做缓存和任务；本地 Ollama 提供模型；Open WebUI 统一管理模型并暴露 `/ollama` API 代理。

3. 数据入库

   甲方提供 3 份 Excel，最终解析出 649 chunks 和 83,456 tokens。Q&A 解析曾遇到 NaN 编码问题，我改用 General 解析方式保证稳定入库。

4. 模型接入

   远端 `50028` 端口实际映射到 Open WebUI 的 `8080`，所以根路径是管理界面，不是 Ollama API。RAGFlow 必须配置为 `http://153.101.206.98:50028/ollama` 才能访问模型。

5. 问题修复

   Embedding 能正常调用，但 Chat 通过 LiteLLM 调 Open WebUI Ollama 代理时报 `Input should be a valid dictionary`。我定位到是 provider 兼容性问题，于是新增原生 `OllamaChat` 适配，使用 `ollama.AsyncClient` 和 Bearer Header 直接调用 `/ollama/api/chat`。

6. 质量优化

   DeepSeek-R1 70B 是 reasoning 模型，可能输出 `<think>`。我在适配层清洗 reasoning 标签，并通过提示词要求只输出客户可见答案。

7. 指标结果

   优化后检索上下文减少 33.33%，候选上限减少 50%，生成上限减少 16.67%，三类问题平均端到端耗时从 236.40 秒降到 206.90 秒，降低 12.48%，格式合规率 3/3，调试词和 reasoning 标签命中为 0。

8. 工具调用

   普通知识问题走 RAGFlow RAG；送礼推荐、销售话术、价格库存这类结构化业务动作走独立 HTTP 工具服务。当前新增 4 个业务工具接口和 1 个 Agent 路由接口，5 个单元测试全部通过，本地规则工具计算耗时低于 1ms。

## 演示前检查

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

访问页面：

```text
http://127.0.0.1:8095
```

登录账号：

```text
test@qq.com / 123
```

## 页面演示路径

1. 打开 RAGFlow 首页。
2. 登录 `test@qq.com`。
3. 进入知识库，展示 `茶` 知识库。
4. 展示 3 份甲方 Excel 文件已经解析完成。
5. 打开聊天助手 `茶园业务问答助手-优化版`。
6. 分别提问茶健康、茶树栽培、茶文化三类问题。
7. 展示回答是分点、可直接给客户看的表达。
8. 启动 `tools\tea_agent_tools\tea_business_tool_server.py`，演示预算 300 元送长辈时工具推荐 `桂香工夫红茶`，并生成销售话术。

## 推荐演示问题

茶健康：

```text
茶叶对健康有哪些可能的益处？请用适合茶园老板向客户解释的语言回答。
```

茶树栽培：

```text
茶树栽培时对土壤和水分管理有哪些注意事项？
```

茶文化：

```text
中国茶文化的发展大致经历了哪些阶段？请简要概括。
```

资料边界测试：

```text
资料中是否提到某个具体茶园今年的产量？如果没有，请说明无法从资料确认。
```

## 面试官可能追问

### 这个项目是不是只是套了 RAGFlow？

回答思路：

```text
RAGFlow 是底座，但我做的是业务落地。工作包括 Docker 部署、远端本地模型接入、Open WebUI Ollama 代理兼容修复、Embedding 默认配置修复、甲方资料解析、知识库验收、业务提示词设计、reasoning 输出清洗和量化测试。特别是 Chat 调用失败的问题需要读 RAGFlow 模型适配代码并修改，不是单纯使用页面功能。
```

### 为什么使用 Open WebUI？

回答思路：

```text
Open WebUI 已经接管了模型服务器上的 Ollama，可以统一管理本地模型和 API Key。RAGFlow 不直接访问 Ollama 根服务，而是通过 Open WebUI 暴露的 `/ollama` 兼容接口访问模型，这样符合现有部署结构，也方便后续模型管理。
```

### 为什么没有直接用更快的模型？

回答思路：

```text
我测试过 `llama3.3:latest`，单句请求 180 秒超时，不适合当前环境。DeepSeek-R1 70B 虽然慢，但回答质量更稳定。我做了参数收敛和输出清洗，最终在保证业务可用的前提下让平均耗时降低 12.48%。另外有一个激进参数版本平均提速 23.86%，但会暴露 reasoning 内容，所以没有作为最终生产配置。
```

### 如何证明优化有效？

回答思路：

```text
我固定茶健康、茶树栽培、茶文化三类问题做前后对比。基线平均耗时 236.40 秒，最终生产配置平均 206.90 秒，降低 12.48%。同时 top_n 从 6 降到 4，top_k 从 1024 降到 512，max_tokens 从 600 降到 500。输出层面，三类问题格式合规率 3/3，禁用词和 `<think>` 命中为 0。
```

### 你的 Agent 或工具调用做了什么？

回答思路：

```text
我补了一个独立 HTTP 工具服务，可以被 RAGFlow Agent/Workflow 调用。它提供茶叶推荐、销售话术生成、价格库存查询和客户问题分流能力。普通茶知识仍然走 RAG；涉及预算、送礼、人群、库存和话术的问题走工具，这样能避免模型编造价格库存，也让销售话术输出更稳定。目前有 4 个业务工具接口、1 个 Agent 路由接口，5 个单元测试全部通过。
```

### 如果上线给企业用，还缺什么？

回答思路：

```text
还需要补监控、评测集和权限审计。我会接入 Langfuse 或 LangSmith 记录 trace、耗时、token、命中文档和用户反馈；构建 20 到 50 个固定问题做回归测试；对不同岗位配置不同知识库和访问权限；同时把 Excel 数据进一步清洗成更标准的 Q&A 或结构化知识。
```

## 简历项目表述

```text
茶园业务知识库 AI 问答助手 | RAGFlow、Docker、Ollama、Open WebUI、DeepSeek-R1 70B、BGE-M3

基于 RAGFlow 二次落地茶园业务知识库问答系统，使用 Docker Compose 部署 MySQL、Elasticsearch、MinIO、Redis 与 RAGFlow 服务，接入 Open WebUI 管理的本地 Ollama 模型。导入甲方 3 份茶业务 Excel 资料，构建 649 个知识片段、83,456 tokens 的知识库，围绕茶健康、茶树栽培、茶文化 3 类问题完成问答验收。修复 RAGFlow 调用 Open WebUI Ollama Chat 代理不兼容问题，新增茶叶推荐、销售话术、价格库存和客户问题分流 HTTP 工具，并通过检索参数、生成参数和提示词优化，将平均端到端耗时由 236.40 秒降至 206.90 秒，降低 12.48%，回答格式合规率达到 3/3，reasoning 标签命中为 0。
```
