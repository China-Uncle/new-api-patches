# Add-Channel-Key Patch

> 新增「仅向渠道追加 key」的接口，脚本场景下替代 `PUT /api/channel/` 全量更新

## 背景

new-api 原生没有「单独追加 key」的接口：

- `POST /api/channel/:id/key`（`GetChannelKey`）—— 仅**读取**密钥，且需 `RootAuth + 安全验证`
- `POST /api/channel/multi_key/manage`（`ManageMultiKeys`）—— 仅 禁用/启用/删除/查状态，**不支持添加**
- `PUT /api/channel/`（`UpdateChannel`）—— 支持 `key_mode:"append"` 追加，但要求先 `GET` 完整渠道对象作为基底，脚本调用不便

本补丁新增一个**只追加 key、零副作用**的接口，调用方只需传 `{"key":"..."}`，无需读取/回写其他字段。

## 补丁内容

修改文件：

| 文件 | 改动 |
|------|------|
| `controller/channel.go` | 新增 `AddChannelKeyRequest` 结构与 `AddChannelKey` handler |
| `router/channel-router.go` | 注册路由 `POST /:id/key/add` |

### 行为

- **路径**：`POST /api/channel/:id/key/add`
- **权限**：`authz.ChannelSensitiveWrite`（与 `PUT /api/channel/` 一致，适合脚本调用）
- **请求体**：`{"key":"<新key>"}`，多个 key 用 `\n` 换行分隔
- **约束**：渠道须为多密钥模式（`ChannelInfo.IsMultiKey == true`），否则报错；不自动开启多密钥
- **语义**：append + 自动去重；兼容换行分隔与 JSON 数组两种现有存储格式
- **副作用**：仅改 `key` 字段，复用 `model.Channel.Update()` 自动重算 `MultiKeySize` 并刷新 `abilities`；记录审计 `channel.add_key`
- **响应**：`{"success":true,"data":{"key_count":N}}`

## 使用方法

### 方式一：脚本应用（推荐）

```bash
git clone https://github.com/China-Uncle/new-api-patches.git
cd new-api-patches
./scripts/apply-patch.sh v1.0.0-rc.25 add-channel-key
```

### 方式二：手动应用

```bash
git clone --depth 1 --branch v1.0.0-rc.25 https://github.com/QuantumNous/new-api.git
cd new-api
git apply /path/to/patches/add-channel-key.patch
docker build -t calciumion/new-api:fix-tools .
```

## 调用示例（curl）

```bash
BASE=https://newapi.chinauncle.eu.org
TOKEN=<具备 ChannelSensitiveWrite 权限的 token>
CHANNEL_ID=2

# 追加单个 key
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"key":"sk-你的新key"}' \
  "$BASE/api/channel/$CHANNEL_ID/key/add"

# 追加多个 key（\n 分隔，自动去重）
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"key":"sk-a\nsk-b"}' \
  "$BASE/api/channel/$CHANNEL_ID/key/add"
```

成功返回：`{"success":true,"data":{"key_count":19}}`。

## 与现有接口对比

| 接口 | 能力 | 调用复杂度 | 适用 |
|------|------|-----------|------|
| `PUT /api/channel/`（`key_mode=append`） | 追加 | 需先 GET 完整对象做基底 | 通用 |
| `POST /api/channel/:id/key/add`（本补丁） | 追加 | 仅传 `{key}` | 脚本 |
| `POST /api/channel/:id/key` | 读 | — | 取密钥明文 |
| `POST /api/channel/multi_key/manage` | 禁用/启用/删除/查状态 | — | 多密钥运维 |

## 注意事项

- 非多密钥渠道调用会返回 `该渠道不是多密钥模式`，需先在 UI 开启多密钥。
- 权限为 `ChannelSensitiveWrite`，与 `PUT /api/channel/` 持平；读密钥（`/:id/key`）反而更严（需 `RootAuth + 安全验证`），本接口不加额外限流以适配脚本高频场景。
- 路由 `/:id/key/add` 与已有 `/:id/key`（读）在 gin radix 树中不同深度，不冲突。
- 补丁基于上游最新 `main` 测试，干净应用、`go build` 通过、`gofmt` 合规。
