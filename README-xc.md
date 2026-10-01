# RustDesk Server — XC 定制版（WebSocket 增强）

本分支在**上游官方 rustdesk-server（1.1.17 开发线）**的基础上加入一小组增强，
目标场景：香港（NAT VPS / 全 wss）与内网（直连）**共用同一份内核**。

## 背景

两处部署共用一套服务栈（hbbs/hbbr + rustdesk-api 管理端）：

- **香港**：NAT VPS，客户端只能经 443 反向代理以 WebSocket (wss) 接入，
  ws 是客户端的**唯一通道**。
- **内网**：UDP/TCP 直连为主，行为保持与官方一致。

上游对 ws 的定位是「辅助短连接」（不支持注册、空闲 30s 断开、无按设备投递），
不足以支撑「ws 作为唯一通道」的部署；此前用旧分叉 + 补丁链解决（已退役）。
本分支把这些能力**重做到官方新代码上**，不再依赖分叉或补丁脚本。

## 改动清单（相对 upstream/master，全部集中在 src/rendezvous_server.rs）

1. **ws 注册支持**：RegisterPeer / RegisterPk / OnlineRequest 在 ws 通道完整处理
   （与 UDP 共享同一份注册核心 `register_pk_core`，行为不漂移）。
2. **ws 连接注册表**：`ws_map`（连接→sink，键=原始 socket 地址，防 NAT 同 IP 碰撞）
   + `ws_id_map`（设备 id→连接）；连接结束时自动清理，不留死路由。
3. **空闲保活**：ws 空闲 20s 发心跳（RegisterPeerResponse{request_pk:true}），
   客户端以空帧回显保持连接；正常消息不再默认断连（仅真实错误断开）。
   —— 消除「30s 断开 → 重连风暴 → 触发限流 → churn」的恶性循环。
4. **按 id 精准投递**：打洞请求转发优先经 ws_id_map 直达目标设备
   （NAT 同 IP 多设备场景正确路由；同时消除对 ws 目标发 UDP 必然失败的问题）。
5. **限流放行**：ws 注册不受 IP 限流硬拒（记录日志并放行，ws 客户端无其它通道可重试）。
6. **ws 保活刷新**：ws 通道的每次 RegisterPk（含心跳回显）都刷新 `last_reg_time`
   （纯 ws 部署的唯一保活路径；缺此条件时设备 30s 后集体被判「离线」）。
7. **健壮性**：UDP 单条消息错误不再重启 UDP 子系统；端口 0 / 无效地址发送直接丢弃。
8. **默认行为边界**：以上 ws 增强仅作用于 ws 通道；纯 TCP 路径保持官方原语义。

## 构建与镜像发布（GitHub Actions）

`.github/workflows/xc-build.yml`（手动触发，或 push `xc/**` 分支自动触发）产出：

1. **all-in-one Docker 镜像**（推荐部署方式）→ 自动推送到 GHCR：

   ```
   ghcr.io/xiaochen301/rustdesk-server-xc:latest
   ghcr.io/xiaochen301/rustdesk-server-xc:<git-sha>
   ```

   镜像 = `lejianwen/rustdesk-server-s6`（s6 all-in-one 基础，香港/内网同款）
   之上覆盖三个定制二进制：
   - `/usr/bin/hbbs`   — 本仓库（xc/ws-enhance）
   - `/usr/bin/hbbr`   — 本仓库
   - `/app/apimain`    — rustdesk-api fork（xiaochen301/rustdesk-api, xc/auto-sync，
                          v2.7 + AutoSyncService 自动入簿）

2. **裸二进制**（fallback / 手动应急）→ workflow artifacts：
   `hbbs` / `hbbr` / `rustdesk-utils`（linux amd64, musl 静态）+ SHA256SUMS。

## 部署（香港 / 内网统一）

```
1. compose 中 image 改为:  ghcr.io/xiaochen301/rustdesk-server-xc:latest
2. docker compose pull && docker compose up -d
3. 验证: 观察者在线查询 + docker logs（update_pk 心跳刷新）
```

- 数据卷（./data）与 env 全部保留，重建无损。
- 回滚：compose 换回原 image（或上一个 sha tag）→ `docker compose up -d`。
- 二进制替换（旧方式，应急）：替换容器内 `/usr/bin/hbbs`、`/app/apimain` 后重启容器。

## 与上游同步

- `upstream` = https://github.com/rustdesk/rustdesk-server
- 升级流程：merge/rebase `upstream/master` → 处理 `src/rendezvous_server.rs`
  冲突（改动集中在发送路径与监听循环）→ 构建 → 香港测试 → 镜像发布 → 部署
