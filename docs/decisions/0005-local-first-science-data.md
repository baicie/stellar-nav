# ADR-0005: 采用版本化本地科学目录与离线校验

## Status

Accepted

## Date

2026-08-06

## Context

MVP 需要稳定、可离线、可测试的科学内容。直接在 App 启动时请求 NASA、JPL 或其他公开 API 会引入网络不可用、上游格式变化、限流、来源版本不明确和测试不确定性。另一方面，手工维护 JSON 又容易出现断开的父引用、未知来源、错误性质或非有限数值。

## Decision

使用版本化本地目录 `data/solar_system_catalog.json` 作为 MVP 权威输入：

- Rust `astro_core` 通过 `include_str!` 将目录绑定到引擎构建；
- 运行时不依赖公开数据 API；
- 目录保存来源 URL、访问时间、对象、轨道参数、科学字段和 provenance；
- Python 离线校验器检查结构、唯一性、数值、来源、层级、系统边界、父循环与数据性质；
- Rust 单元和 bridge contract tests 检查目录能被实际运行时加载并正确传播；
- 数据更新通过明确的 catalog version 进入版本控制，不能在客户端静默替换。

未来接入 SPICE、Horizons、TLE / OMM 或表面瓦片时，Python 工具链负责获取、锁定、转换、许可记录和质量报告；App 仍消费已验证、可复现的产物。

`tile_decoder` 当前只定义并验证离线包 manifest。离线包下载、签名、更新和瓦片渲染不属于现成能力。

## Alternatives Considered

### App 启动时直接请求公开 API

- 优点：数据可能更新；
- 缺点：不可离线、不可复现，受上游可用性和格式影响，也难以让用户知道具体数据版本；
- 结论：MVP 拒绝。

### 只依赖 Rust 反序列化是否成功

- 优点：工具更少；
- 缺点：合法 JSON 仍可能有重复 ID、断开引用、未知来源、错误性质和 NaN / Infinity；
- 结论：增加语义校验器与针对性测试。

### 在 Flutter assets 中直接解析目录

- 优点：Dart 侧访问简单；
- 缺点：目录与 Rust 计算可能加载不同版本，Widget 也会越过 repository 边界；
- 结论：Rust 引擎是运行时目录 owner，Flutter 通过 bridge 获取。

### MVP 引入 PostgreSQL 或对象存储

- 优点：方便大数据与在线更新；
- 缺点：当前 16 对象目录不需要服务端，增加运维和隐私边界；
- 结论：推迟到真实在线需求出现。

## Consequences

- 相同 commit 的数据与计算可复现；
- App 可在没有网络时浏览当前目录和计算教学路线；
- 数据更新需要提交目录、版本和验证结果；
- 公开来源变化不会在运行时突然改变用户结果；
- 实时星历与实时空间天气明确不在当前能力内；
- 未来数据量增大时需要设计离线包、增量更新和许可策略。
