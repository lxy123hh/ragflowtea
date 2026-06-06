# 阶段一：本地环境启动与验收记录

## 项目名称

茶园业务本地化 AI 知识助手平台。

项目路径：

```text
D:\study\project\tea\ragflowtea
```

Docker Compose 目录：

```text
D:\study\project\tea\ragflowtea\docker
```

## 阶段目标

验证 RAGFlow 本地部署环境是否可以正常启动，并为后续阶段做准备：

- 本地大模型接入
- 茶园业务知识库创建
- 甲方 Excel 数据导入
- RAG 问答效果调优
- Langfuse 链路监控
- 最终简历材料与验收文档整理

## Git 状态核查

当前分支：

```text
master
```

跟踪分支：

```text
github/master
```

已配置远程仓库：

```text
github  git@github.com:lxy123hh/ragflowtea.git
origin  git@gitee.com:jiangsu-university-linlin/ragflowtea.git
```

说明：

- `github` 用于推送到 GitHub。
- `origin` 是 Gitee 远程仓库。
- 后续阶段提交优先推送到 `github master`。

## Docker 环境核查

Docker 版本：

```text
Docker version 28.1.1
```

Docker Compose 版本：

```text
Docker Compose version v2.35.1-desktop.1
```

Docker 当前上下文：

```text
desktop-linux
```

Docker 后端：

```text
Docker Desktop + WSL2 Linux Engine
```

结论：

Docker 与 Docker Compose 版本满足 RAGFlow 本地启动要求，当前使用 Linux 容器环境。

## Compose 服务核查

Compose 文件中包含以下服务：

```text
es01
minio
mysql
ragflow-cpu
redis
```

启动命令：

```powershell
cd D:\study\project\tea\ragflowtea\docker
docker compose -f docker-compose.yml up -d
```

状态检查命令：

```powershell
docker compose -f docker-compose.yml ps
```

## 服务运行状态

当前观察到的服务状态：

| 服务 | 容器名 | 状态 | 端口映射 |
| --- | --- | --- | --- |
| Elasticsearch | docker-es01-1 | healthy | 1200 -> 9200 |
| MinIO | docker-minio-1 | healthy | 9000-9001 -> 9000-9001 |
| MySQL | docker-mysql-1 | healthy | 5455 -> 3306 |
| Redis / Valkey | docker-redis-1 | healthy | 6380 -> 6379 |
| RAGFlow | docker-ragflow-cpu-1 | running | 8095 -> 80，9380-9382 -> 9380-9382，443 -> 443 |

RAGFlow Web 访问地址：

```text
http://127.0.0.1:8095
```

验收结果：

```text
HTTP 200
```

RAGFlow 后端 API 端口：

```text
http://127.0.0.1:9380
```

验收结果：

```text
访问 / 根路径返回 HTTP 404，符合预期，因为 API 根路径不是页面路由。
```

RAGFlow 容器日志关键证据：

```text
RAGFlow version: v0.24.0
Use Elasticsearch http://es01:9200 as the doc engine.
Elasticsearch http://es01:9200 is healthy.
RAGFlow ingestion is ready.
RAGFlow server is ready.
Running on http://0.0.0.0:9380
task_executor reported heartbeat.
```

结论：

RAGFlow Web、后端服务、任务执行器和依赖组件均已启动，阶段一环境启动通过。

## 甲方数据源记录

甲方提供了三份 Excel 文件，作为茶园业务知识库的初始数据源：

| 文件说明 | 文件路径 | 文件大小 |
| --- | --- | --- |
| 茶树栽培与发展历史问答 | `D:\download\Chrome_download\茶树栽培与发展历史问答.xlsx` | 462981 bytes |
| 茶文化学 | `D:\download\Chrome_download\茶文化学.xlsx` | 144334 bytes |
| 茶文化与茶健康 | `D:\download\Chrome_download\茶文化与茶健康.xlsx` | 1288773 bytes |

说明：

- 三份文件均已确认存在。
- 后续将在知识库构建阶段导入。
- 导入前需要先完成账号准备、模型配置和知识库创建。

## 测试账号需求

后续需要创建一个用于验收和演示的测试账号：

```text
用户名：test
密码：123
```

说明：

- 该账号仅用于本地测试和演示。
- 生产环境不能使用该弱密码。
- 账号创建将在账号初始化或系统配置阶段完成，并单独记录验收结果。

## 阶段一验收清单

- [x] 已检查 Git 仓库状态。
- [x] 已确认 GitHub 远程仓库。
- [x] 已确认 Docker 引擎可用。
- [x] 已确认 Docker Compose 可用。
- [x] 已确认 Compose 服务定义可解析。
- [x] 已确认 RAGFlow 依赖容器运行中。
- [x] MySQL 状态 healthy。
- [x] Redis / Valkey 状态 healthy。
- [x] MinIO 状态 healthy。
- [x] Elasticsearch 状态 healthy。
- [x] RAGFlow 容器运行中。
- [x] RAGFlow Web 返回 HTTP 200。
- [x] RAGFlow 后端日志显示 server ready。
- [x] 已确认三份甲方 Excel 数据文件存在。
- [x] 已记录测试账号需求。

## 阶段一结论

阶段一通过。

本地 RAGFlow 部署环境已经启动并可访问，可以进入阶段二：本地模型接入与测试账号准备。

