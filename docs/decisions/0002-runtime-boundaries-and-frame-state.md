# ADR-0002: 隔离产品状态、计算请求与逐帧渲染状态

## Status

Accepted

## Date

2026-08-06

## Context

地图需要连续星光、航线和航行器动画，同时还要处理搜索、路线、时间轴、图层和任务状态。若每帧更新 Riverpod，会扩大 Widget 重建范围；若每帧跨 `flutter_rust_bridge` 调用 Rust，还会增加序列化、调度和平台边界成本。

科学结果只在目录加载、搜索、起终点或提交时间变化时更新，不需要与显示刷新率绑定。

## Decision

运行时数据流固定为：

```text
Widget intent
    -> NavigatorController / Riverpod
    -> NavigationRepository
    -> flutter_rust_bridge facade
    -> deterministic Rust crate
    <- versioned immutable result
```

边界规则：

- Riverpod 保存低频、可描述的产品状态；
- `AnimationController`、`CustomPainter` 和手势本地状态保存逐帧或连续瞬态；
- 时间轴拖动期间只更新 Widget 本地预览，释放后才提交时刻并调用 Rust；
- Widget 通过 `NavigationRepository` 访问计算能力，不直接调用 FRB 生成函数；
- 只有 `astro_engine` 依赖 `flutter_rust_bridge`，领域 crate 不依赖 Flutter 或平台 API；
- bridge 只暴露目录、来源、搜索、位置、窗口和路线等低频操作；
- 不从 painter、ticker 或帧 callback 调用 Rust。

bridge 当前使用版本化 JSON envelope。JSON 不是为了逐帧吞吐，而是为了让 Dart 与 Rust contract 可检查、可版本化，并减少生成 DTO 与领域 DTO 的耦合。

## Alternatives Considered

### 把所有动画进度存入 Riverpod

- 优点：所有状态集中；
- 缺点：每帧触发 provider 通知和潜在 Widget 重建，难以约束性能；
- 结论：拒绝。

### 每帧从 Rust 请求天体坐标

- 优点：计算逻辑全部集中在 Rust；
- 缺点：bridge、JSON 和线程边界进入热路径；当前教学轨迹完全可以在离散时刻求解后由 Flutter 插值；
- 结论：拒绝。

### Widget 直接调用生成 bridge API

- 优点：文件更少；
- 缺点：UI 与 FFI、序列化和生成代码强耦合，测试替身困难；
- 结论：通过 `NavigationRepository` 隔离。

### bridge 直接暴露所有 Rust struct

- 优点：减少 JSON 解析；
- 缺点：生成类型会向 UI 扩散，跨语言结构升级更难控制；
- 结论：MVP 使用低频版本化 JSON，性能证据出现后再评估二进制或强类型 contract。

## Consequences

- 连续动画不会导致 Riverpod 每帧更新；
- Rust 计算保持确定性且可以独立测试；
- 时间、路线和目录更新是明确的离散事件；
- Flutter 与 Rust 需要维护平行 DTO 和 contract tests；
- 若未来对象数量大到需要逐帧原生场景计算，应新建渲染边界 ADR，而不是绕过本规则。
