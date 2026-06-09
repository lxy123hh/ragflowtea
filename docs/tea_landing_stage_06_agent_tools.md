# 阶段六补充：茶园业务 Agent 工具调用能力验收

## 阶段目标

补齐原计划中的“茶园业务 Agent 或工具调用能力”。本阶段实现一个轻量 HTTP 工具服务，让项目不只停留在知识库问答，还能处理茶园老板和销售人员的具体业务动作。

本阶段采用计划中允许的轻量方案：

```text
实现一个后端独立 API，封装茶叶推荐、销售话术、价格库存查询和客户问题分流能力。
```

该服务可以独立演示，也可以作为 RAGFlow Agent/Workflow 的 HTTP 工具调用。

## 新增文件

| 文件 | 作用 |
| --- | --- |
| `tools/tea_agent_tools/tea_business_tool_server.py` | 茶园业务 HTTP 工具服务 |
| `tools/tea_agent_tools/README.md` | 工具服务启动、接口和调用说明 |
| `test/tea_agent_tools/test_tea_business_tools.py` | 工具逻辑单元测试 |

## 工具能力

| 接口 | 能力 | 业务价值 |
| --- | --- | --- |
| `POST /tools/recommend_tea` | 根据预算、口味、用途、人群、是否送礼、是否新手推荐茶品 | 支持送礼推荐、客户选品 |
| `POST /tools/generate_sales_script` | 生成销售人员可直接使用的话术 | 支持门店或线上客服沟通 |
| `POST /tools/query_inventory` | 查询演示用价格和库存 | 避免模型编造价格和库存 |
| `POST /tools/classify_question` | 判断客户问题类型并给出处理方式 | 区分产品、冲泡、送礼、价格、售后、健康风险 |
| `POST /agent/handle_customer` | 对客户问题做分流并调用合适工具 | 模拟 Agent 工具路由 |

## 启动方式

### Docker Compose 启动

本阶段已将工具服务容器化，推荐使用 Docker Compose 启动。工具容器复用 `${RAGFLOW_IMAGE}` 镜像并挂载工具脚本，不需要额外拉取 Python 基础镜像。

进入 Docker 目录：

```powershell
cd D:\study\project\tea\ragflowtea\docker
```

启动工具服务：

```powershell
docker compose -f docker-compose.yml up -d tea-agent-tools
```

服务地址：

| 访问方 | 地址 |
| --- | --- |
| RAGFlow 容器内 | `http://tea-agent-tools:18088` |
| RAGFlow Agent/Workflow OpenAPI | `http://tea-agent-tools:18088/openapi.json` |
| 宿主机浏览器或命令行 | `http://127.0.0.1:18088` |

容器互通验证：

```powershell
docker compose -f docker-compose.yml exec ragflow-cpu python -c "import urllib.request; print(urllib.request.urlopen('http://tea-agent-tools:18088/health').read().decode())"
```

预期返回：

```json
{"status": "ok", "service": "tea-agent-tools"}
```

### Python 直接启动

进入项目根目录：

```powershell
cd D:\study\project\tea\ragflowtea
```

启动工具服务：

```powershell
python tools\tea_agent_tools\tea_business_tool_server.py --host 127.0.0.1 --port 18088
```

健康检查：

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:18088/health" -Method Get
```

OpenAPI 描述：

```text
http://127.0.0.1:18088/openapi.json
```

## RAGFlow Agent/Workflow 接入方式

在 RAGFlow Agent 或 Workflow 中新增 HTTP 工具时，可以使用：

```text
Base URL: http://tea-agent-tools:18088
OpenAPI: http://tea-agent-tools:18088/openapi.json
```

推荐接入顺序：

1. 普通知识类问题继续走 RAGFlow 知识库问答。
2. 客户送礼、预算、口味、人群相关问题调用 `/tools/recommend_tea`。
3. 需要客服话术时调用 `/tools/generate_sales_script`。
4. 涉及价格或库存时调用 `/tools/query_inventory`，避免 LLM 编造。
5. 无法判断问题类型时先调用 `/tools/classify_question`。

## 验收测试

### 单元测试

执行命令：

```powershell
python test\tea_agent_tools\test_tea_business_tools.py
```

结果：

```text
Ran 5 tests in 0.000s
OK
```

覆盖能力：

- 送礼预算推荐。
- 销售话术生成。
- 红茶价格库存查询。
- 健康风险问题分流。
- 客户问题自动路由到推荐工具。

### HTTP 接口验收

启动服务后执行接口级测试，结果如下：

```json
{
  "health": "ok",
  "recommend_top": "桂香工夫红茶",
  "recommend_price": 298,
  "recommend_latency_ms": 0,
  "script_product": "桂香工夫红茶",
  "script_steps": 5,
  "script_latency_ms": 0,
  "route_type": "product_consulting",
  "route_tool": "recommend_tea",
  "route_latency_ms": 0
}
```

说明：

- 本地规则工具计算耗时低于 1ms，接口返回中按毫秒整数记录为 `0`。
- 推荐工具能根据“300 元预算、送长辈、温和口味”推荐 `桂香工夫红茶`。
- 销售话术工具生成 5 步沟通话术。
- Agent 路由接口能识别客户咨询，并调用 `recommend_tea`。

## 工具调用与普通 RAG 的区别

普通 RAG 适合回答：

- 茶文化历史是什么？
- 茶树栽培要注意什么？
- 茶叶健康资料中有哪些说法？

工具调用适合处理：

- 客户预算 300 元送长辈，应该推荐哪款？
- 某款茶多少钱、库存多少？
- 销售人员应该怎么跟客户介绍？
- 客户问题是否涉及售后或健康风险，是否需要人工介入？

区别在于：

- RAG 强在资料检索和事实回答。
- 工具强在结构化业务动作、稳定输出和边界控制。
- 价格、库存、推荐规则不应该完全交给 LLM 自由生成，应由工具返回确定结果。

## 面试可讲内容

可以这样解释：

```text
在 RAG 问答之外，我补了一个茶园业务工具服务，提供茶叶推荐、销售话术、价格库存查询和客户问题分流接口。普通茶知识问题仍然走 RAGFlow 知识库检索；涉及预算、送礼、人群、库存和销售话术的问题，由 Agent/Workflow 调用 HTTP 工具返回结构化结果。这样可以避免模型编造价格库存，也能让销售话术输出更稳定。
```

量化表述：

```text
- 新增 4 个业务工具接口和 1 个 Agent 路由接口。
- 覆盖茶叶推荐、销售话术、价格库存、客户问题分流 4 类业务动作。
- 编写 5 个单元测试，工具逻辑测试通过率 5/5。
- 完成 3 个 HTTP 接口验收调用，健康检查、推荐、话术和路由均通过。
- 本地规则工具计算耗时低于 1ms，适合作为 RAG 问答前后的确定性业务工具。
```

## 阶段验收结论

阶段六补充达成：

- 已实现茶园业务后端工具服务。
- 已完成可被 Agent/Workflow 调用的 HTTP 接口。
- 已完成单元测试和 HTTP 验收。
- 已补齐“茶叶知识库问答 + 推荐/话术/查询工具”的完整演示链路。

该阶段补齐后，项目可以更稳地作为“AI 应用落地 + RAG + 工具调用”的面试主项目。
