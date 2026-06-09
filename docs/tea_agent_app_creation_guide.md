# RAGFlow 茶园销售咨询 Agent 创建指南

## 目标

将已容器化的茶园业务工具服务接入 RAGFlow Agent App，让项目具备：

```text
茶知识 RAG 问答 + 茶叶推荐/销售话术/价格库存/问题分流工具调用
```

## 前置条件

### 1. RAGFlow 已启动

```bash
cd /www/wwwroot/ragflow-0.24.0/docker
docker compose -f docker-compose.yml up -d
```

本地开发环境：

```powershell
cd D:\study\project\tea\ragflowtea\docker
docker compose -f docker-compose.yml up -d
```

### 2. 启动茶园业务工具容器

```bash
docker compose -f docker-compose.yml up -d tea-agent-tools
```

### 3. 验证宿主机可访问

```bash
curl http://127.0.0.1:18088/health
```

预期：

```json
{
  "status": "ok",
  "service": "tea-agent-tools"
}
```

### 4. 验证 RAGFlow 容器内可访问

```bash
docker compose -f docker-compose.yml exec ragflow-cpu python -c "import urllib.request; print(urllib.request.urlopen('http://tea-agent-tools:18088/health', timeout=5).read().decode())"
```

预期返回同样的健康检查 JSON。

## Agent 页面创建

打开：

```text
http://127.0.0.1:8095/agents
```

远端：

```text
http://mjkj.szhxyj.com.cn:8095/agents
```

如果页面有三个创建选项，优先选择：

```text
空白创建 / Blank / Create from scratch
```

如果没有空白创建，再选择类似：

```text
Workflow Agent / Tool Calling Agent / Customer Service Agent
```

暂时不要选择“导入 DSL”，除非后续需要手写流程。

## Agent 基本信息

名称：

```text
茶园销售咨询 Agent
```

描述：

```text
基于茶园知识库和业务工具，处理茶叶知识问答、送礼推荐、销售话术、价格库存和客户问题分流。
```

## 模型配置

Chat Model：

```text
deepseek-r1:70b@Ollama
```

Embedding Model：

```text
bge-m3:latest@Ollama
```

知识库：

```text
茶
```

如果 Agent 页面允许绑定知识库，绑定 `茶` 知识库；如果 Agent 和 Chat App 分开配置，则普通知识库问答仍可保留在 `茶园业务问答助手-优化版` 中。

## 系统提示词

建议填入：

```text
你是茶园销售咨询 Agent，服务对象是茶园老板和销售人员。

规则：
1. 茶文化、茶树栽培、茶健康等资料型问题，优先基于茶园知识库回答。
2. 涉及预算、送礼、人群、口味偏好、价格库存、销售话术的问题，优先调用茶园业务工具。
3. 客户询问价格或库存时，必须调用价格库存工具，不要自行编造。
4. 客户询问医疗功效时，不要承诺治疗效果，只能说明资料中的茶饮信息，并建议必要时咨询专业人士。
5. 输出要适合销售人员直接转述给客户，分点说明，简洁明确。
6. 如果工具返回了推荐结果，要说明推荐理由、冲泡建议和注意事项。
```

## 添加 HTTP / OpenAPI 工具

如果页面支持 OpenAPI 导入，填写：

```text
http://tea-agent-tools:18088/openapi.json
```

如果页面要求 Base URL，填写：

```text
http://tea-agent-tools:18088
```

如果页面要手动添加工具接口，按下面填写。

### 工具一：茶叶推荐

名称：

```text
recommend_tea
```

URL：

```text
http://tea-agent-tools:18088/tools/recommend_tea
```

Method：

```text
POST
```

JSON Body 示例：

```json
{
  "budget": 300,
  "taste": "温和",
  "purpose": "送礼",
  "crowd": "长辈",
  "gift": true,
  "beginner": false
}
```

### 工具二：销售话术

名称：

```text
generate_sales_script
```

URL：

```text
http://tea-agent-tools:18088/tools/generate_sales_script
```

Method：

```text
POST
```

JSON Body 示例：

```json
{
  "budget": 300,
  "taste": "温和",
  "purpose": "送礼",
  "crowd": "长辈",
  "customer_need": "客户想给长辈买一盒不踩雷的茶"
}
```

### 工具三：价格库存查询

名称：

```text
query_inventory
```

URL：

```text
http://tea-agent-tools:18088/tools/query_inventory
```

Method：

```text
POST
```

JSON Body 示例：

```json
{
  "product_name": "桂香工夫红茶"
}
```

### 工具四：客户问题分流

名称：

```text
classify_question
```

URL：

```text
http://tea-agent-tools:18088/tools/classify_question
```

Method：

```text
POST
```

JSON Body 示例：

```json
{
  "question": "客户预算300元，想送长辈，应该推荐哪款茶？"
}
```

### 工具五：Agent 路由

名称：

```text
handle_customer
```

URL：

```text
http://tea-agent-tools:18088/agent/handle_customer
```

Method：

```text
POST
```

JSON Body 示例：

```json
{
  "question": "客户预算300元，想送长辈，应该推荐哪款茶？",
  "budget": 300,
  "purpose": "送礼",
  "crowd": "长辈",
  "gift": true
}
```

## 推荐测试问题

### 1. 送礼推荐

```text
客户预算300元，想送长辈，应该推荐哪款茶？
```

预期：

- 调用 `recommend_tea` 或 `handle_customer`。
- 推荐 `桂香工夫红茶`。
- 说明价格 `298`、适合长辈、适合送礼、冲泡建议和注意事项。

### 2. 销售话术

```text
客户想买一款口感温和、不踩雷的茶，帮我生成一段销售话术。
```

预期：

- 调用 `generate_sales_script`。
- 输出销售人员可直接转述的话术。

### 3. 价格库存

```text
桂香工夫红茶还有库存吗？多少钱？
```

预期：

- 调用 `query_inventory`。
- 返回价格 `298`、库存 `18`。
- 不由模型自行编造价格。

### 4. 健康风险

```text
茶叶有没有治疗高血压的作用？
```

预期：

- 不承诺治疗效果。
- 可调用 `classify_question` 识别为 `health_risk`。
- 建议只按资料说明一般茶饮信息。

## 验收记录

容器化工具服务已完成以下验收：

| 验收项 | 结果 |
| --- | --- |
| `tea-agent-tools` 容器启动 | 通过 |
| 宿主机访问 `/health` | 通过 |
| RAGFlow 容器访问 `http://tea-agent-tools:18088/health` | 通过 |
| `/agent/handle_customer` 推荐路由 | 通过 |
| 推荐结果 | `桂香工夫红茶` |
| 推荐价格 | `298` |
| 工具计算耗时 | 低于 1ms |

## 面试说明

可以这样讲：

```text
我把茶园业务工具服务容器化后加入 RAGFlow 的 Docker Compose 网络，RAGFlow Agent 可以通过容器 DNS `tea-agent-tools:18088` 调用工具。普通茶知识问题仍然走 RAGFlow 知识库，预算、送礼、库存、销售话术等业务动作走 HTTP 工具，避免 LLM 自由编造价格和库存，也让推荐逻辑更稳定。
```
