# 茶园业务 Agent 工具服务

该目录提供一个轻量 HTTP 工具服务，用于补齐“茶园知识库问答 + 业务工具调用”的 Agent 能力。它可以独立演示，也可以作为 RAGFlow Agent/Workflow 的 HTTP 工具调用。

## 工具能力

| 接口 | 能力 |
| --- | --- |
| `POST /tools/recommend_tea` | 根据预算、口味、用途、人群、是否送礼、是否新手推荐茶品 |
| `POST /tools/generate_sales_script` | 生成销售人员可直接使用的话术 |
| `POST /tools/query_inventory` | 查询演示用价格和库存，避免模型编造价格 |
| `POST /tools/classify_question` | 判断客户问题类型，并给出下一步处理方式 |
| `POST /agent/handle_customer` | 对客户问题做分流，并调用合适的业务工具 |

## 启动

### Docker Compose 启动

在 `docker` 目录执行。该服务复用 `${RAGFLOW_IMAGE}` 镜像并挂载工具脚本，不需要额外拉取 Python 基础镜像。

```powershell
docker compose -f docker-compose.yml up -d tea-agent-tools
```

RAGFlow 容器内访问地址：

```text
http://tea-agent-tools:18088
```

Agent / Workflow 中推荐使用：

```text
http://tea-agent-tools:18088/openapi.json
```

本机或服务器外部访问：

```text
http://127.0.0.1:18088
```

验证容器互通：

```powershell
docker compose -f docker-compose.yml exec ragflow-cpu python -c "import urllib.request; print(urllib.request.urlopen('http://tea-agent-tools:18088/health').read().decode())"
```

### Python 直接启动

在项目根目录执行：

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

## 调用样例

茶叶推荐：

```powershell
Invoke-RestMethod `
  -Uri "http://127.0.0.1:18088/tools/recommend_tea" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"budget":300,"taste":"温和","purpose":"送礼","crowd":"长辈","gift":true,"beginner":false}'
```

销售话术：

```powershell
Invoke-RestMethod `
  -Uri "http://127.0.0.1:18088/tools/generate_sales_script" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"budget":300,"taste":"温和","purpose":"送礼","crowd":"长辈","customer_need":"客户想给长辈买一盒不踩雷的茶"}'
```

客户问题分流：

```powershell
Invoke-RestMethod `
  -Uri "http://127.0.0.1:18088/agent/handle_customer" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"question":"客户预算300元，想送长辈，应该推荐哪款茶？","budget":300,"purpose":"送礼","crowd":"长辈","gift":true}'
```

## 和普通 RAG 的区别

普通 RAG 主要回答“资料里有什么”。业务工具调用用于处理“需要结构化业务动作”的问题，例如：

- 推荐茶品需要预算、口味、人群、用途等结构化参数。
- 价格库存不应由模型自由生成，应由工具返回。
- 销售话术需要稳定模板，避免每次风格失控。
- 售后、健康风险问题需要分流或提示人工介入。

因此演示时可以先用 RAGFlow 回答茶文化、栽培、健康知识，再用该工具服务演示送礼推荐、库存查询和销售话术生成。
