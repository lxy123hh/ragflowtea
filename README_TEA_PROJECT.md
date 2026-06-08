# 茶园业务知识库 AI 问答助手

这是基于 RAGFlow 二次落地的茶园业务 AI 应用项目。项目面向茶园老板的真实业务资料，将甲方提供的茶树栽培、茶文化、茶健康 Excel 文件构建为本地知识库，并接入 Open WebUI 管理的本地 Ollama 模型，实现可演示、可验收、可写入简历的 RAG 问答系统。

## 项目亮点

- 本地 Docker Compose 部署 RAGFlow、MySQL、Elasticsearch、MinIO、Redis。
- 接入 Open WebUI 管理的本地 Ollama 模型，Chat 使用 `deepseek-r1:70b`，Embedding 使用 `bge-m3:latest`。
- 导入甲方 3 份茶业务 Excel 资料，构建 649 个知识片段、83,456 tokens。
- 修复 RAGFlow 调用 Open WebUI Ollama Chat 代理不兼容问题。
- 清洗 `deepseek-r1:70b` reasoning 输出，避免 `<think>` 内容暴露给业务用户。
- 优化检索和生成参数，最终三类问题平均端到端耗时由 236.40 秒降至 206.90 秒，降低 12.48%。
- 三类核心问题格式合规率 3/3，调试词和 reasoning 标签命中为 0。

## 技术栈

```text
RAGFlow、Docker Compose、MySQL、Elasticsearch、MinIO、Redis、Ollama、Open WebUI、DeepSeek-R1 70B、BGE-M3、RAG、Embedding、向量检索、提示词工程、模型代理适配、知识库解析、问答质量评测
```

## 快速启动

```powershell
cd D:\study\project\tea\ragflowtea\docker
docker compose -f docker-compose.yml up -d
```

访问：

```text
RAGFlow Web: http://127.0.0.1:8095
RAGFlow API: http://127.0.0.1:9380
```

测试账号：

```text
test@qq.com / 123
```

## 文档入口

| 文档 | 说明 |
| --- | --- |
| [最终交付文档](docs/tea_project_final_delivery.md) | 项目背景、架构、数据、模型接入、问题修复、验收指标和简历写法 |
| [面试演示脚本](docs/tea_interview_demo_script.md) | 30 秒介绍、2 分钟讲解、演示路径和追问回答 |
| [阶段 1 环境验收](docs/tea_landing_stage_01_environment.md) | Docker 和 RAGFlow 本地环境启动验收 |
| [阶段 2 账号与模型](docs/tea_landing_stage_02_account_model.md) | 测试账号、Chat 模型、Embedding 模型配置 |
| [阶段 3 知识库导入](docs/tea_landing_stage_03_knowledgebase_import.md) | 甲方 Excel 导入、解析和知识库规模 |
| [阶段 4 问答验收](docs/tea_landing_stage_04_qa_acceptance.md) | 茶健康、栽培、文化三类问答验收 |
| [阶段 5 优化指标](docs/tea_landing_stage_05_optimization_resume_metrics.md) | 参数优化、reasoning 清洗、量化指标和简历成果 |

## 与原 RAGFlow 框架的关系

RAGFlow 是本项目的底座。本仓库中的茶园项目工作重点是业务落地和二次适配，包括：

- 本地化部署和服务联调。
- Open WebUI 管理的 Ollama 模型接入。
- RAGFlow 模型适配代码修复。
- 甲方业务数据入库和解析策略选择。
- 面向茶园老板场景的问答应用配置。
- 输出质量优化、验收测试和简历材料沉淀。

原 RAGFlow 官方说明见 [README.md](README.md)。
