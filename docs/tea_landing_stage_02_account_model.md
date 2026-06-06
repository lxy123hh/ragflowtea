# 阶段二：测试账号与本地模型接入验收记录

## 阶段目标

完成茶园业务 AI 知识助手的基础账号和模型准备工作，为后续知识库导入、问答测试和效果调优做准备。

本阶段验收内容：

- 创建本地演示账号 `test / 123`。
- 为 `test` 账号补齐 RAGFlow 所需的租户、用户-租户关系、根文件夹。
- 为 `test` 账号配置 Ollama Chat Model 和 Embedding Model。
- 验证 `test / 123` 可以登录。
- 验证登录后可以看到已配置的 Ollama 模型。

## 当前服务状态

RAGFlow Compose 服务仍处于运行状态。

核心服务：

| 服务 | 状态 |
| --- | --- |
| RAGFlow | running |
| MySQL | healthy |
| Redis / Valkey | healthy |
| MinIO | healthy |
| Elasticsearch | healthy |

Web 访问地址：

```text
http://127.0.0.1:8095
```

后端 API 地址：

```text
http://127.0.0.1:9380
```

## 默认模型配置

当前 Docker 配置模板 `docker/service_conf.yaml.template` 中已有默认模型配置：

```yaml
user_default_llm:
  factory: 'Ollama'
  api_key: 'empty'
  base_url: 'http://153.101.206.98:50028'
  default_models:
    chat_model:
      name: 'deepseek-r1:70b'
    embedding_model:
      name: 'bge-m3:latest'
    rerank_model: ''
```

RAGFlow 容器启动日志也显示了相同默认模型：

```text
default embedding config: {'model': 'bge-m3:latest@Ollama', 'factory': 'Ollama', 'api_key': 'empty', 'base_url': 'http://153.101.206.98:50028'}
user_default_llm: {'factory': 'Ollama', 'api_key': 'empty', 'base_url': 'http://153.101.206.98:50028', 'default_models': {'chat_model': {'name': 'deepseek-r1:70b'}, 'embedding_model': {'name': 'bge-m3:latest'}}}
```

说明：

- `deepseek-r1:70b` 用作 Chat Model。
- `bge-m3:latest` 用作 Embedding Model。
- 当前未配置 Rerank Model。
- `http://153.101.206.98:50028` 返回 Open WebUI 页面，`/ollama/api/tags` 需要认证，因此本阶段不直接用外部未认证接口做模型生成验收。
- 模型的端到端生成能力将在阶段三/阶段四通过知识库问答和文档解析任务继续验收。

## 测试账号创建

目标账号：

```text
用户名：test
密码：123
```

RAGFlow 登录接口实际使用 `email` 字段。为了满足本地演示账号为 `test / 123` 的要求，本阶段创建了：

```text
email: test
nickname: test
password: 123
```

账号创建方式：

- 使用容器内 Python 调用 RAGFlow 数据库服务层完成。
- 密码使用 RAGFlow 登录逻辑要求的格式存储：先对明文 `123` 做 base64，再由 `UserService.save()` 生成密码哈希。
- 补齐用户对应的 tenant、user_tenant、tenant_llm 和根文件夹记录。

## 创建过程中的问题与修复

第一次创建时，用户基础记录已写入，但租户创建失败：

```text
Column 'parser_ids' cannot be null
```

原因：

当前容器内 `settings.PARSERS` 为空，直接使用该值创建 tenant 会导致 `parser_ids` 为空。

修复方式：

使用 RAGFlow 初始化逻辑中的默认解析器列表补齐 tenant：

```text
naive:General,qa:Q&A,resume:Resume,manual:Manual,table:Table,paper:Paper,book:Book,laws:Laws,presentation:Presentation,picture:Picture,one:One,audio:Audio,email:Email,tag:Tag
```

第二次修复时，tenant 和 user_tenant 创建成功，但 `get_init_tenant_llm()` 在当前默认配置格式下报错：

```text
TypeError: string indices must be integers, not 'str'
```

修复方式：

不再调用 `get_init_tenant_llm()`，而是按当前 Ollama 默认模型配置直接写入 `tenant_llm`：

| 模型类型 | 模型工厂 | 模型名称 | API Base |
| --- | --- | --- | --- |
| embedding | Ollama | bge-m3:latest | http://153.101.206.98:50028 |
| chat | Ollama | deepseek-r1:70b | http://153.101.206.98:50028 |

同时补齐根文件夹：

```text
name: /
type: folder
```

## 账号数据验收

容器内数据库验收结果：

```text
user=test
tenant_llm_id=deepseek-r1:70b@Ollama
tenant_embd_id=bge-m3:latest@Ollama
tenant_rerank_id=
models=Ollama/embedding/bge-m3:latest/http://153.101.206.98:50028;Ollama/chat/deepseek-r1:70b/http://153.101.206.98:50028
```

说明：

- `test` 用户存在。
- `test` 用户对应的 tenant 存在。
- `test` 用户对应的 user_tenant 关系存在。
- `test` 用户对应的根文件夹存在。
- `test` 用户对应的 Ollama Chat/Embedding 模型配置存在。

## 登录接口验收

通过容器内 Python 调用 RAGFlow 登录接口：

```text
POST http://127.0.0.1:9380/v1/user/login
```

请求账号：

```text
email: test
password: 123
```

验收结果：

```text
status=200
code=0
email=test
nickname=test
```

结论：

`test / 123` 登录成功。

## 模型配置接口验收

登录后调用：

```text
GET http://127.0.0.1:9380/v1/llm/my_llms?include_details=true
```

验收结果：

```json
{
  "code": 0,
  "data": {
    "Ollama": {
      "llm": [
        {
          "api_base": "http://153.101.206.98:50028",
          "max_tokens": 8192,
          "name": "bge-m3:latest",
          "status": "1",
          "type": "embedding",
          "used_token": 0
        },
        {
          "api_base": "http://153.101.206.98:50028",
          "max_tokens": 8192,
          "name": "deepseek-r1:70b",
          "status": "1",
          "type": "chat",
          "used_token": 0
        }
      ],
      "tags": "LLM,TEXT EMBEDDING,SPEECH2TEXT,MODERATION"
    }
  },
  "message": "success"
}
```

结论：

`test` 账号登录后可以读取到 Ollama 的 Chat Model 和 Embedding Model 配置。

## 当前模型验收边界

本阶段已完成：

- 模型配置写入。
- 模型配置在 RAGFlow 用户侧可见。
- 测试账号可登录并读取模型配置。

本阶段未做：

- 未直接调用 `deepseek-r1:70b` 做生成验收。
- 未直接调用 `bge-m3:latest` 做 embedding 验收。

原因：

- 当前 `153.101.206.98:50028` 对外表现为 Open WebUI，部分 Ollama 代理接口需要认证。
- 70B 模型生成可能耗时较长。
- 真实模型调用更适合在阶段三知识库导入后，通过文档解析、向量化和问答流程做端到端验收。

后续验收安排：

- 阶段三：导入三份甲方 Excel，观察文档解析和 embedding 是否正常。
- 阶段四：通过茶园业务测试问题验证 Chat Model 的问答生成能力。

## 阶段二验收清单

- [x] 已确认 RAGFlow 服务仍处于运行状态。
- [x] 已确认默认模型配置来自 Ollama。
- [x] 已确认 Chat Model 为 `deepseek-r1:70b`。
- [x] 已确认 Embedding Model 为 `bge-m3:latest`。
- [x] 已创建 `test / 123` 测试账号。
- [x] 已补齐 test 用户 tenant。
- [x] 已补齐 test 用户 user_tenant。
- [x] 已补齐 test 用户根文件夹。
- [x] 已补齐 test 用户 Ollama Chat/Embedding 模型记录。
- [x] 已验证 `test / 123` 登录成功。
- [x] 已验证登录后可读取 Ollama 模型配置。

## 阶段二结论

阶段二通过。

测试账号和模型配置已经准备完成，可以进入阶段三：茶园业务知识库创建与三份甲方 Excel 数据导入。

