# ADR-0006: 统一 Flutter、Rust、数据与 Web 质量门禁

## Status

Accepted

## Date

2026-08-06

## Context

项目同时包含 Dart、Flutter Widget、Rust workspace、生成 bridge、WebAssembly 和 Python 数据工具。只运行某一语言的测试无法发现跨语言字段漂移、生成文件过期、目录错误或 Web 构建失败。开发者与 CI 若使用不同命令，也容易出现“本地通过、合并失败”。

仓库路径包含中文时，当前 Flutter 工具的 `flutter analyze` wrapper 还会因 LSP 消息解析崩溃，而 `dart analyze` 可以正常分析源码。

## Decision

根目录 `./scripts/verify.sh` 是提交前和 GitHub Actions `CI` 工作流的共同入口。门禁覆盖：

- Dart 格式检查；
- `dart analyze` 静态分析；
- 构建宿主 Rust 动态库，并通过标准 Flutter 测试实际初始化 FRB 与 Repository；
- Flutter 单元与 Widget 测试；
- Rust `cargo fmt`、Clippy `-D warnings` 和 workspace tests；
- 锁定 WASM 依赖图的 Rust 三方许可证生成测试、清单漂移与发行载荷检查；
- Python 目录校验器测试与仓库目录验证；
- FRB 生成物漂移检查；
- Rust WebAssembly 生成与一致性；
- Flutter Web production build。
- Flutter Web production build 中的项目 MIT、字体 OFL、Flutter/Dart notices 与 Rust 三方清单。

测试分层：领域 crate 证明算法与数据边界，bridge contract tests 证明跨语言 payload，宿主动态库冒烟测试证明真实 FRB 初始化与 Repository 调用，controller / Widget tests 证明用户状态与无障碍行为，Python tests 证明离线输入完整性，Web build 证明交付链路。

视觉地图改动还需要手工或浏览器自动化检查目标视口、console、非空 canvas 和遮挡；构建成功不能替代视觉验收。

## Alternatives Considered

### 每个开发者自行选择命令

- 优点：灵活；
- 缺点：检查集合不一致，容易漏掉跨语言边界；
- 结论：窄范围命令可用于迭代，提交前必须运行统一入口。

### CI 重写一套独立步骤

- 优点：YAML 日志更细；
- 缺点：本地和 CI 容易漂移；
- 结论：CI 调用同一脚本，脚本本身保持可读和失败即停。

### 使用 `flutter analyze`

- 优点：Flutter 项目的常见命令；
- 缺点：当前中文 workspace 路径触发工具级 LSP 解析崩溃；
- 结论：使用等价源码分析的 `dart analyze`，工具问题修复后再评估恢复。

### 只测试 Rust 或只测试 Flutter

- 优点：更快；
- 缺点：无法证明数据、contract 和产品流程整体一致；
- 结论：聚焦测试用于开发循环，完整门禁覆盖全部层。

## Consequences

- 本地复现 CI 只需要一个命令；
- 行为、数据和 contract 漂移更早失败；
- 标准 `flutter test` 不依赖设备也能覆盖一次真实 Rust bridge 启动；
- 完整验证耗时高于单语言测试，因此开发中仍鼓励先跑窄范围检查；
- WebAssembly 工具版本必须锁定并在环境文档中声明；
- 缺少随 crate 分发的许可正文时，覆盖文件必须绑定精确包版本并记录官方来源，升级后重新审计；
- iOS / Android 完整包仍依赖外部原生工具链，若环境缺失必须如实记录未验证风险。
