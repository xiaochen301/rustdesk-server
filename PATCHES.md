# PATCHES — xiaochen301/rustdesk-server fork（分支 xc/ws-enhance）

> 治理规则：见 skill `tech-debt-governance`。补丁提交统一 `patch:` 前缀，`git log --grep=patch:` 可全量筛查。
> 本 fork 的 ws 增强历史（RD-001~007 等价物）见提交史与 `~/.hermes/patches/rustdesk-hbbs-xc/`。

## 已登记补丁

### [XC-PATCH-RD-008] hbbs: WebRTC 信令转发（offer / answer / ICE 路由）[激活]

| 项 | 内容 |
|----|------|
| 打入日期 | 2026-10-06 |
| 目标 | `src/rendezvous_server.rs` + 子模块 `libs/hbb_common`（69cea8d → 229b9045，客户端 1.5.0 配套 pin） |
| 内容 | ① `PunchHoleRequest.webrtc_sdp_offer` → `PunchHole.webrtc_sdp_offer`（转给受控端）② `PunchHoleSent.webrtc_sdp_answer` → `PunchHoleResponse.webrtc_sdp_answer`（回给控制器）③ 新增 `IceCandidate` 消息路由：echo 地址 → `tcp_punch` 送达控制器 punch 连接；`id` → `ws_id_map` 送达受控端主连接；④ `send_to_tcp` / `send_to_tcp_sync` 改为不摘除 sink（trickle 复用同一连接多次投递；连接关闭时统一清理） |
| 原因 | 客户端 1.5.0 的 WebRTC（ICE）直连需要服务端配套转发（PR rustdesk/rustdesk#15684 "Server-side requirement"：forward the SDP fields, route IceCandidate in both directions, keep candidate-carrying TCP connections open）。官方开源服务端（master 停 2026-08-07）与官方 PR 均未发布该改动，为保 ws/443 部署恢复 P2P 直连而先行实现 |
| 验证 | ① 本地编译通过（rust:1.95-alpine，同 CI）② 香港实测：跨网连接日志出现 offer/answer/ICE 转发与 WebRTC 直连证据（待补） |
| 拆除条件 | 上游 rustdesk-server 发布配对实现后，评估切换官方实现并移除本地转发逻辑（本条目转 [已解决]） |
| 备注 | 仅转发不解析 SDP；候选连接保活依赖既有 ws 保活机制（RD-007 系列） |
