docker\migration.sh

docker\migrate_to_vllm.sh

```
docker compose exec -T mysql mysql -uroot -pinfini_rag_flow rag_flow -e "
UPDATE tenant
SET llm_id='qwen3@VLLM',
    embd_id='bge-m3@VLLM';

UPDATE dialog
SET llm_id='qwen3@VLLM'
WHERE status='1'
  AND (llm_id LIKE '%@Ollama' OR llm_id LIKE '%deepseek%');

UPDATE knowledgebase
SET embd_id='bge-m3@VLLM',
    parser_config=JSON_SET(COALESCE(parser_config, JSON_OBJECT()), '$.llm_id', 'qwen3@VLLM')
WHERE status='1';

SELECT id,name,llm_id,embd_id FROM tenant;
SELECT id,name,llm_id,kb_ids FROM dialog WHERE status='1' ORDER BY create_time DESC LIMIT 20;
"
```

  1. 改 YAML 配置 — service_conf.yaml.template 里 user_default_llm 从原来的 Ollama 改成 VLLM 工厂 + qwen3/bge-m3/qwen-vl，指向 litellm 代理地址，带上 sk-ragflow-local 密钥。
   2. 改数据库 — migrate_to_vllm.sh 做的事：往 tenant_llm 表给每个租户插入 VLLM 模型记录（llm_name 带 ___VLLM后缀），再更新 tenant 表的 llm_id / embd_id 指向这些新记录。这让已有用户能在下拉框里看到并选中 VLLM 模型。
