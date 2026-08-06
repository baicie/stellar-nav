# ADR-0001: 采用 Flutter、Rust 与 Python 的分层平台

## Status

Accepted

## Date

2026-08-06

## Context

产品需要同时满足地图式移动交互、自绘太阳系场景、确定性科学计算、iOS / Android / Web 跨平台，以及未来接入更大天文数据集的能力。用户要求彻底停止旧 Expo 代码线，并以新产品设计和新架构为唯一基线。

当前 MVP 不需要账号、后端或运行时科学数据下载，但需要让 UI、计算和离线数据处理可以分别演进。

## Decision

采用三层技术栈：

- Flutter 3.44 / Dart 3.12 负责 App、响应式布局、手势、无障碍和自绘地图；
- Rust workspace 负责确定性目录、简化星历、窗口、路线、搜索、空间索引和离线格式；
- Python 标准库工具负责离线数据校验，未来可扩展为公开数据获取、转换和质量报告工具链。

Flutter 与 Rust 通过 `flutter_rust_bridge` 连接。只有 `native/astro_engine` 是平台桥接 facade；`native/crates/*` 保持平台无关。当前不引入运行时后端或数据库。

旧 Expo、React Native、TypeScript、Skia、Reanimated、Zustand 和 pnpm 实现被明确退役，不能继续作为新功能落点。

## Alternatives Considered

### 保留 Expo / React Native 并重写页面

- 优点：已有 JavaScript / TypeScript 生态和旧构建配置；
- 缺点：与用户要求的架构重置冲突，也会继续携带旧状态、渲染和发布约束；
- 结论：拒绝。

### 全部使用 Flutter / Dart

- 优点：单语言、工具链更简单；
- 缺点：核心模型难以独立复用到桌面、服务或批处理，未来高计算量星历与空间索引的演进空间较小；
- 结论：不采用，Flutter 保持产品层，Rust 提供可复用内核。

### 全部使用 Rust 与原生 UI

- 优点：统一核心语言和精细性能控制；
- 缺点：移动端 UI、响应式交互和无障碍开发成本显著更高；
- 结论：不适合消费级地图 App 的 MVP。

### 首版即加入后端

- 优点：便于在线更新和统一计算；
- 缺点：增加部署、隐私、离线可用性和故障面，而 MVP 数据量不需要；
- 结论：推迟，后续需求必须另做 ADR。

## Consequences

- UI 与科学计算可以独立测试和演进；
- Rust 核心可以在未来被桌面端、服务或离线工具复用；
- 项目需要同时维护 Flutter、Rust、FRB、WASM 和原生平台工具链；
- bridge 生成物和跨语言 contract 必须进入统一质量门禁；
- Python 只用于离线工具，不进入 App 运行时或逐帧路径；
- 旧 Expo 发布与 CI 文档不再适用于当前代码线。
