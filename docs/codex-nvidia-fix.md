# Codex → NVIDIA GLM-5.2 Patch

> 适配 Codex Responses API 到 NVIDIA Chat Completions 的补丁

## 背景

Codex 使用 OpenAI Responses API（`POST /v1/responses`），NVIDIA 上游只支持 Chat Completions（`POST /v1/chat/completions`）。此补丁在 new-api 侧完成转换，Codex 端零改动。

## 补丁内容

修改文件：`relaykit/relayconvert/internal/oai_responses/to_oai_chat_req.go`

| 改动 | 说明 |
|------|------|
| 过滤非 function 工具 | 跳过 `namespace`/`web_search` 等，避免 NVIDIA 拒绝 |
| function 工具嵌套读取 | 支持 `{"type":"function","function":{"name":...}}` 格式 |
| tool_choice 降级 | 非 function tool_choice 降级为 `"auto"` |
| 丢弃 prompt_cache_key | NVIDIA 不支持该字段 |

## 使用方法

### 方式一：脚本应用（推荐）

```bash
git clone https://github.com/China-Uncle/new-api-patches.git
cd new-api-patches
./scripts/apply-patch.sh v1.0.0-rc.25
```

### 方式二：手动应用

```bash
# 1. 克隆官方仓库
git clone --depth 1 --branch v1.0.0-rc.25 https://github.com/QuantumNous/new-api.git
cd new-api

# 2. 应用补丁
git apply /path/to/patches/responses-to-chat.patch

# 3. 构建
docker build -t new-api:patched .
```

### 方式三：从 patch 分支 cherry-pick

```bash
# 直接从本仓库 patch 分支 cherry-pick
git remote add patches https://github.com/China-Uncle/new-api-patches.git
git fetch patches patch
git cherry-pick patches/patch
```

## 配套数据库配置

渠道类型需改为 **58 (Advanced Custom)**，`settings` 列配置：

```json
{"advanced_custom": {"advanced_routes": [
  {"incoming_path": "/v1/responses", "upstream_path": "/v1/chat/completions",
   "converter": "openai_responses_to_openai_chat_completions"},
  {"incoming_path": "/v1/chat/completions", "upstream_path": "/v1/chat/completions"},
  {"incoming_path": "/v1/models", "upstream_path": "/v1/models"},
  {"incoming_path": "/pg/chat/completions", "upstream_path": "/v1/chat/completions"}
]}}
```

## 与上游同步

本仓库配置了 GitHub Actions 自动同步：

- **main 分支**：每周自动 force push，与上游 100% 同步
- **patch 分支**：自动 rebase 到最新 main
- **冲突处理**：自动创建 Issue 通知手动解决

### 手动同步

```bash
# 同步上游
git fetch upstream main
git checkout main
git reset --hard upstream/main
git push origin main --force

# Rebase 补丁
git checkout patch
git rebase origin/main
git push origin patch --force
```

## 冲突解决

如果 rebase 失败，需要手动修改 `to_oai_chat_req.go`：

1. 查看 `.rej` 文件了解冲突位置
2. 按以下要点手动合并：
   - L97-103: 删除 `PromptCacheKey` 处理代码
   - L342-358: 添加 `firstNonEmpty` 辅助函数和嵌套读取逻辑
   - L365-368: 非 function 工具跳过（continue）
   - L403-405: 返回 `"auto"` 而非 `choice`
3. `git add . && git rebase --continue`

## 验证结果

| 场景 | 结果 |
|------|------|
| `/v1/responses` 流式 | 200 ✅ |
| Codex 全套工具 | 200 ✅ |
| `prompt_cache_key` | 200 ✅ |
| Codex 实测 | 可用 ✅ |

## 注意事项

- 补丁基于 `v1.0.0-rc.25` 测试，其他版本可能需要微调
- NVIDIA 免费 tier 响应较慢（60s~300s+）
- 非流式 `/v1/responses` 不可用（NVIDIA 强制 SSE）
