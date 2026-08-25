# Fetch-Models Sticky-Proxy Patch

> 修复多密钥 + 粘性代理渠道“获取模型列表”报错 `invalid proxy URL`，支持 `{KEY}` 占位符与全量重试

## 背景

部分渠道为多密钥模式，且配置粘性代理：

```
socks5h://Default.{KEY}:5be1b4831fcadf40d97fb6a20c384446@172.21.0.1:2260
```

`{KEY}` 为占位符，期望每个 key 映射到独立代理用户（固定出口 IP）。但现有代码：

- `ChannelSettings.Proxy` 为渠道级单值，`fetchChannelUpstreamModelIDs` 仅 `GetNextEnabledKey()` 取 **单 key** 单次探活
- `common/proxy_url.go:30` `url.Parse("...{KEY}...")` 因 `userinfo` 含 `{` `}` 未编码直接失败 → `invalid proxy URL`
- 多密钥渠道因此所有 `POST /api/channel/fetch_models/:id` 必现 `获取模型列表失败: invalid proxy URL`

## 补丁内容

| 文件 | 改动 |
|------|------|
| `common/proxy_url.go` | 新增 `ResolveProxyURL(rawProxy, key)`：替换 `{KEY}/{key}/{{KEY}}/{{key}}/${KEY}/${key}` 占位符并做 `userinfo` 编码；新增 `sanitizeProxyURLLine`：多行代理取首行，兼容粘贴多行场景；`parseProxyURL` 入口改用 `sanitizeProxyURLLine` |
| `controller/channel_upstream_update.go` | 新增 `getFetchModelsResponseBodyWithProxy`（proxy 可覆盖）、`isProxyConfigError`、`isRetryableFetchError`、`orderedEnabledKeys`、`resolveProxyForKey`；改造 `fetchChannelUpstreamModelIDs` 与 `fetchAdvancedCustomUpstreamModelIDs` 为 **策略 C**：首试 `GetNextEnabledKey`（复用 `Random/Polling`），失败按存储顺序遍历剩余 `enabled` keys，最后若 `proxy != ""` 则 **直连兜底**（再次遍历所有 enabled keys 不走代理）；`Ollama`/`Gemini`/`AdvancedCustom`/`默认 OpenAI` 四分支均覆盖 |

### 行为

- **占位符**：`socks5h://Default.{KEY}:pass@host:port` → 每次用当前尝试的 `key` 替换，key 自动 `QueryEscape` 编码（`:`/`@` 等安全），无占位符则原样共享单代理
- **遍历策略（C）**：
  1. 首试 `GetNextEnabledKey()`（尊重 `MultiKeyModeRandom/Polling` 配置）
  2. 失败则按 `GetKeys()` 存储顺序遍历剩余 `enabled` keys（过滤 `MultiKeyStatusList` 非 `Enabled`）
  3. 若 `proxy` 含配置且此前失败，执行 **直连兜底**：用空代理再次遍历所有 enabled keys，任一成功即返回并 `SysLog` 记录 `fallback to direct`
- **重试判定**：`proxy URL` 解析错误 → 跳出 key 循环转直连；`401/403/429/5xx` → 换下一 key；其余错误也尝试下一 key 以最大化发现成功率
- **兼容**：非多密钥渠道保持单 key 语义；`Codex` 保持原拒绝多密钥逻辑

## 使用方法

### 方式一：脚本应用（推荐）

```bash
git clone https://github.com/China-Uncle/new-api-patches.git
cd new-api-patches
./scripts/apply-patch.sh v1.0.0-rc.25 fetch-models-sticky-proxy
# 或应用全部补丁
./scripts/apply-patch.sh v1.0.0-rc.25
```

### 方式二：手动应用

```bash
git clone --depth 1 --branch v1.0.0-rc.25 https://github.com/QuantumNous/new-api.git
cd new-api
git apply /path/to/patches/fetch-models-sticky-proxy.patch
docker build -t calciumion/new-api:fix-tools .
```

## 配置示例

渠道 `setting.proxy` 填：

```
socks5h://Default.{KEY}:5be1b4831fcadf40d97fb6a20c384446@172.21.0.1:2260
```

支持的占位符：`{KEY}`、`{key}`、`{{KEY}}`、`{{key}}`、`${KEY}`、`${key}`（大小写兼容）。

若无粘性需求，仍填普通单代理 `socks5h://user:pass@host:port`，补丁无影响。

## 验证结果

| 场景 | 结果 |
|------|------|
| 多密钥 + `socks5h://Default.{KEY}:...` | 按 key 顺序遍历，首失败自动试下一 key ✅ |
| 代理含 `{KEY}` 且 key 含 `:`/`@` | 自动编码，`url.Parse` 成功 ✅ |
| 多行代理粘贴 | 取首行，`invalid proxy URL` 消失 ✅ |
| 所有 key 失败 + 代理有效 | 直连兜底重试，日志 `fallback to direct` ✅ |
| 单密钥渠道 | 单次探活，无额外开销 ✅ |
| `go vet ./common ./controller` | 通过 ✅ |

## 注意事项

- 渠道须为多密钥模式才会遍历；非多密钥保持原单 key 逻辑。
- `Polling` 模式的 `MultiKeyPollingIndex` 仅首试推进一次，后续顺序遍历不再推进，避免污染转发状态。
- 直连兜底仅在 `proxy != ""` 且此前失败时触发一次（再次遍历所有 enabled keys）。
- 补丁基于 `v1.0.0-rc.25` 测试，`git apply --check` 干净、`go vet` 通过。
