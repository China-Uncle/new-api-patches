# new-api-patches

独立补丁仓库，用于 [QuantumNous/new-api](https://github.com/QuantumNous/new-api) 的定制化修改。

## 补丁列表

| 补丁 | 说明 | 适用场景 |
|------|------|----------|
| [responses-to-chat](patches/responses-to-chat.patch) | Codex Responses API → NVIDIA Chat Completions 转换 | Codex + NVIDIA GLM |
| [add-channel-key](patches/add-channel-key.patch) | 新增 `POST /api/channel/:id/key/add` 仅追加 key 接口 | 脚本批量为渠道追加密钥 |
| [fetch-models-sticky-proxy](patches/fetch-models-sticky-proxy.patch) | 修复多密钥+粘性代理获取模型 `invalid proxy URL`，支持 `{KEY}` 占位符与全量重试 | 多密钥粘性代理渠道 |

## 快速开始

```bash
# 1. 克隆本仓库
git clone https://github.com/China-Uncle/new-api-patches.git
cd new-api-patches

# 2. 应用补丁并构建（默认应用全部补丁，也可指定单个）
./scripts/apply-patch.sh v1.0.0-rc.25              # 应用全部
./scripts/apply-patch.sh v1.0.0-rc.25 add-channel-key   # 仅应用某个补丁

# 3. 部署（需在目标服务器执行）
cd /opt/new-api
# 编辑 docker-compose.yml，将 image 改为 calciumion/new-api:fix-tools
docker compose up -d
```

## 分支说明

| 分支 | 用途 |
|------|------|
| `main` | 与上游 100% 同步，只读 |
| `patch` | 包含所有定制补丁 |

## 自动同步

GitHub Actions 配置：

- **sync-upstream.yml**：每周一自动同步上游 main，并尝试 rebase patch 分支
  - 成功 → 自动 push 更新
  - 冲突 → 自动创建 Issue 通知手动解决
- **build-test.yml**：push 到 patch 分支时自动构建验证

## 手动同步上游

```bash
# 同步 main
git fetch upstream main
git checkout main
git reset --hard upstream/main
git push origin main --force

# Rebase 补丁
git checkout patch
git rebase origin/main
# 若冲突，解决后：
git add . && git rebase --continue
git push origin patch --force
```

## 补丁详情

- [docs/codex-nvidia-fix.md](docs/codex-nvidia-fix.md)
- [docs/add-channel-key.md](docs/add-channel-key.md)
- [docs/fetch-models-sticky-proxy.md](docs/fetch-models-sticky-proxy.md)

## 许可证

本仓库仅包含补丁文件，不包含 new-api 源码。new-api 原项目使用 AGPL-3.0 许可证。
