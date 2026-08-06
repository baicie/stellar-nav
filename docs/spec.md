# Spec: 天枢导航太阳系科普 MVP

## Status

- 状态：Implemented baseline，仍需持续做多视口视觉验收
- 基线日期：2026-08-06
- 产品名：天枢导航 / AstroNav
- 当前数据域：太阳系 `sol`

## Assumptions

1. 首版服务于对太阳系和航天概念感兴趣的普通用户，优先让用户看懂，不假设其具备轨道力学背景。
2. 科幻风格是表达方式，不是伪造科学确定性的理由；真实资料、推导、模拟和虚构必须始终可区分。
3. MVP 是 iOS、Android 和 Web 可运行的本地优先 App，不依赖账号、后端或运行时网络数据。
4. 当前轨道与路线模型只用于科普和交互演示，不满足工程任务精度。
5. 先完成太阳系导航闭环，再通过稳定 ID、版本 contract 和尺度适配扩展到恒星或星系。

## Objective

构建一个采用地面地图交互范式的太阳系导航 App。用户打开应用后直接进入地图，可以搜索天体或设施、查看带来源的科学事实、观察时间变化带来的轨道演化、比较多种任务路线，并启动一段明确标注为模拟的导航演示。

成功体验应同时做到：

- 像地图 App：入口直接、搜索自然、路线可比较、控件位置可预测；
- 像科普产品：每个关键值说明“它是什么、从哪里来、可信到什么程度”；
- 像科幻作品：视觉有深空氛围，但不牺牲阅读、无障碍和事实边界；
- 像可演进系统：当前只运行 `sol`，数据和计算接口可以增加其他系统而不重写现有 ID。

## Product Scope

### In scope

1. 太阳系地图
   - 航线聚焦视图和完整太阳系视图；
   - 天体、轨道、设施、航线、通信、空间天气与风险图层；
   - 平移、缩放、重置、对象点选和选中反馈。
2. 搜索与详情
   - 简体中文、英文名称和别名搜索；
   - 天体类型、状态、简介、科学字段、来源与数据性质；
   - 从详情把可达对象设置为目的地。
3. 路线规划
   - 选择或交换起终点；
   - 比较最快、最省燃料、最低风险三种策略；
   - 展示航时、距离、Delta-v、通信时延、风险、推荐分、教学窗口质量和途经节点。
4. 时间系统
   - 显示 UTC 教学时刻；
   - 按天或 30 天步进，滑动预览并在提交时刷新位置与路线；
   - 返回现实时间。
5. 模拟导航
   - 开始和结束任务；
   - 在地图与 HUD 中展示路线进度和阶段提示；
   - 始终显示“模拟导航”和任务用途免责声明。
6. 数据与平台
   - 内置版本化太阳系目录；
   - iOS、Android 和 Web Flutter 工程；
   - Flutter / Rust bridge 与离线 Python 校验工具。

### Not in MVP

- SPICE、JPL Horizons 或遥测驱动的实时高精度位置；
- Lambert solver、摄动、多体问题、姿态、推力和燃料工程仿真；
- 可操作的 3D 太阳系或行星表面导航；
- 其他恒星系统、银河系或跨星际路线的运行时数据；
- 账号、云同步、社区、支付、遥测、推送和后端服务；
- 离线包下载、更新、容量管理和完整瓦片渲染；
- 将空间天气或风险示意用于真实任务决策。

## Core User Flows

### 浏览与科普

1. 用户进入 App，看到默认“国际空间站到阿尔忒弥斯月面基地”教学任务。
2. 用户切换到太阳系视图并缩放、平移或点选天体。
3. 用户查看对象详情、科学字段、来源和数据性质。

### 搜索与路线

1. 用户在顶部搜索框输入“火星”或 `Mars`。
2. 用户打开火星详情并选择“导航到火星”。
3. App 重新计算三条策略路线。
4. 用户比较航时、Delta-v、通信时延、风险和教学窗口后选择策略。

### 时间与模拟导航

1. 用户打开时间轴，预览并提交新的 UTC 日期。
2. App 重新计算教学位置、教学窗口评分和候选路线。
3. 用户启动导航，地图动画与 HUD 运行，但帧进度不进入全局状态或 Rust。
4. 用户结束导航，已选路线和时间仍可继续检查。

## Data Contract

### Catalog

权威本地目录是 `data/solar_system_catalog.json`，当前版本为 `2026.08-solar-mvp`。目录包含来源表和 16 个对象。每个对象至少包括：

- 稳定 `id`；
- 所属 `systemId`；
- 可空 `parentId`；
- 中英文名称、别名、类型和可达性；
- 可选教学轨道参数；
- 轨道参数组自身的 `provenance`；
- 科学字段列表；
- 对象级与字段级 `provenance`。

对象 ID 使用分层命名，例如 `sol/earth/moon` 和 `sol/earth/moon/artemis-base`。`parentId` 表达数据层级，`orbit.parentId` 表达当前教学轨道的参考中心；两者都必须引用有效对象并保持同一系统。

### Data nature

仅允许四种性质：

| Nature | Required meaning |
| --- | --- |
| `observed` | 有公开来源的观测或权威资料快照 |
| `derived` | 根据声明输入与方法计算、换算或整理 |
| `simulated` | 根据教学模型和策略假设生成 |
| `fictional` | 明确属于科幻设定，现实中不宣称存在 |

`provenance` 至少包含 `nature`、`sourceId` 和中文说明。来源至少包含稳定 ID、标签、URL 与 UTC 访问时间。UI 必须同时用文字和视觉标记表达性质。

### Runtime calculations

- `ephemeris_engine` 以简化 J2000 轨道要素和确定性开普勒求解生成位置：观测或推导对象输出 `derived`，模拟对象保持 `simulated`，虚构对象保持 `fictional`；
- `time_engine` 对行星间路线使用圆轨道、共面霍曼转移目标相位，对同一中心天体内路线使用局部轨道周期时机近似；由于输入相位是目录演示基准，教学窗口输出必须标记 `simulated`，不得表述为任务级发射窗口；
- `route_engine` 将起终点、地月 L1 中继节点与转移边组成显式航路图；边成本是航时、Delta-v、距离、风险、通信和窗口的教学代理，载具能力由内置声明式 profile（航程、允许的行星域、支持模式、单边 Delta-v 上限和系数）约束，再按最快、燃料、风险权重做确定性 Dijkstra 多目标搜索，输出必须标记 `simulated`，不得解释为实测燃料、风险或任务推荐；
- 相同目录、输入与时刻必须得到相同结果；
- 不支持的起终点返回空候选集，不能补造路线。

### Bridge

Flutter 通过 `NavigationRepository` 调用 `astro_engine`。桥接 payload 使用 camelCase JSON envelope，并带：

- `schemaVersion`：结构兼容版本；
- `catalogVersion`：计算所用目录版本；
- 时间相关响应的 `dayFromJ2000`；
- `data`：实际结果。

搜索、目录、位置、窗口与路线是低频调用。任何逐帧绘制、镜头或航行器插值都不得跨 bridge。

## Tech Stack

- Flutter `3.44.8` / Dart `3.12.2`；
- Riverpod `3.4.2`；
- Lucide Flutter icons `3.1.15`；
- Flutter `CustomPainter` 与 `AnimationController`；
- Rust `1.96.0`，edition 2021 workspace，workspace 禁止 `unsafe_code`；
- `flutter_rust_bridge` / codegen `2.12.0`；
- Python 3 标准库离线校验；
- Flutter test、Rust test、Python unittest 和 Web build 作为质量证明。

不使用 Expo、React Native、TypeScript、Skia、Reanimated、Zustand 或 pnpm。它们属于已经退役的旧实现，不是备选运行时。

## Project Structure

```text
lib/main.dart                         初始化 Rust 与 Provider overrides
lib/src/app/                          Flutter App 与启动错误界面
lib/src/design/                       颜色、间距和主题令牌
lib/src/domain/                       Dart DTO 与格式化
lib/src/features/navigation/          页面、Controller、Repository 与控件
lib/src/rust/                         FRB 生成代码
native/astro_engine/                  FRB facade 与 contract tests
native/crates/astro_core/             目录模型、版本和 provenance
native/crates/ephemeris_engine/       确定性教学星历
native/crates/route_engine/           多策略教学路线
native/crates/search_core/            中英文目录搜索
native/crates/spatial_index/          视口空间筛选底层能力
native/crates/tile_decoder/           离线包 manifest 格式底层能力
native/crates/time_engine/            霍曼目标相位与教学窗口评分
data/                                 版本化太阳系目录
tools/data_pipeline/                  Python 离线校验器
tools/release/                        Android 发布元数据与工作流测试
test/                                 Dart 单元与 Widget 测试
integration_test/                     Flutter 集成测试
docs/decisions/                       ADR
scripts/                              本地和 CI 统一门禁
```

依赖方向为：

```text
widgets -> controller -> repository -> generated bridge -> astro_engine
                                                        -> domain crates
domain crates -> astro_core / standard Rust dependencies
data pipeline -> catalog JSON -> astro_core include_str!
```

领域 crate 不依赖 Flutter、平台 API 或 `flutter_rust_bridge`。Flutter Widget 不直接调用生成 bridge 或读取原始 JSON。

## Commands

完整验证：

```bash
flutter pub get
./scripts/verify.sh
```

聚焦验证与运行：

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
dart analyze lib test integration_test
flutter test
(cd native && cargo fmt --all -- --check)
(cd native && cargo clippy --workspace --all-targets -- -D warnings)
(cd native && cargo test --workspace)
python3 -m unittest discover -s tools/data_pipeline/tests -p 'test_*.py'
flutter_rust_bridge_codegen generate
flutter run -d chrome
flutter run -d <device-id>
```

`./scripts/verify.sh` 负责补充生成物漂移、WebAssembly 和 `flutter build web` 检查。仓库路径含中文时使用 `dart analyze`，因为当前 `flutter analyze` wrapper 存在与源码无关的 LSP 消息解析问题。

Web 发行包必须保留项目 MIT、Noto Sans SC 的 OFL、Flutter/Dart notices，以及从锁定 WASM Cargo 依赖图生成的 Rust 三方许可清单。crate 声明许可证但未随包提供正文时，只允许使用精确版本、记录官方来源 URL 的审计覆盖；依赖升级后不得自动沿用旧覆盖。

## Code Style

代码标识符和文件名使用英文，产品文案和无障碍名称使用简体中文。Dart 遵循 `flutter_lints` 和 `dart format`，Rust 遵循 `cargo fmt`、Clippy 和 workspace `unsafe_code = "forbid"`。

数据性质必须使用封闭枚举，不接受含糊的自由文本分类：

```dart
enum DataNature {
  observed,
  derived,
  simulated,
  fictional;
}
```

- 优先不可变 DTO、显式类型、语义化命名和小范围模块；
- 注释解释科学近似、性能原因或 contract 约束，不复述代码；
- 不手改生成 bridge；
- 不用颜色作为数据性质、风险或选中状态的唯一提示；
- 不让 Widget 知道 Rust 序列化细节。

## State And Rendering

Riverpod 状态可以包含：目录、搜索结果、对象选择、已提交模拟日期、候选路线、策略、面板、图层和任务开始 / 结束。

Riverpod 状态不得包含：每帧航行器进度、星点闪烁相位、镜头插值、手势中的连续瞬态或 painter tick。连续值留在 `AnimationController` 和 `CustomPainter`。时间轴拖动只更新 Widget 本地预览，`onChangeEnd` 才触发位置和路线计算。

持续动画遵循系统“减少动态效果”偏好；偏好开启时环境与航线控制器停止推进，但静态地图、路线信息和全部操作仍可使用。

Rust 调用仅发生在目录加载、搜索、提交时间、修改起终点或请求路线等离散事件。不得从 `paint`、ticker 或帧回调调用 Rust。

## Testing Strategy

1. Rust unit tests
   - 目录层级和来源引用；
   - 相同时刻的确定性位置与时间变化；
   - 会合周期、路线策略差异，以及位置与轨道参数组的数据性质；
   - 中英文搜索、空间筛选和离线包 schema。
2. Rust bridge contract tests
   - JSON 可解析；
   - schema / catalog version；
   - `systemId`、provenance 和三种路线策略。
3. Dart controller tests
   - 默认 ISS 到月面基地任务；
   - 搜索、目的地、时间和导航状态迁移；
   - 帧进度不进入产品状态。
   - 宿主 Rust 动态库可初始化，真实 Repository 可读取目录、位置和三种路线。
4. Flutter Widget tests
   - 中文首屏；
   - 搜索火星、详情和重新规划；
   - 路线策略、停靠摘要、图层、时间轴与导航 HUD；
   - 中文 tooltip 与 semantics label。
5. Python tests
   - JSON 结构、唯一性、层级、来源、性质、UTC 时间与有限数值；
   - 仓库实际目录必须零错误。
6. Build and visual checks
   - bridge 生成物无漂移，WASM 运行时契约和 Web 构建通过；
   - `flutter build web` 成功；
   - 320 x 568、390 x 844、平板和宽屏无重叠、裁切、空白画布或控制台错误。
7. Android beta packaging
   - 普通 CI 使用临时证书验证 release 构建，不向 pull request 暴露正式签名材料；
   - annotated prerelease tag 只允许指向 `main`，正式证书由 GitHub Secrets 注入；
   - GitHub Release 只提供 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三个 APK，并校验包名、版本、唯一 ABI、`libastro_engine.so`、证书与 SHA-256；
   - 产物不可原地覆盖，撤回后使用更高 `versionCode` 和同一证书发布修复包。

不以未测量的 FPS 或启动耗时冒充已达标指标。当前不可协商的性能门禁是：逐帧过程不写 Riverpod、不跨 FRB，静态与行为测试稳定，视觉检查确认地图非空且交互层不遮挡。

## Boundaries

### Always

- 保留四类数据性质与来源链；
- 为行为、算法、contract 和目录规则增加相应测试；
- 提交前运行 `./scripts/verify.sh`；
- 新增中文文案时提供可理解的中文无障碍名称；
- 让太阳系内导航流程先保持完整可用；
- 在范围或不可逆技术决策变化时同步规格和 ADR。

### Ask first

- 运行时联网、账号、后端、数据库、遥测或用户数据收集；
- 新增依赖、3D 引擎、云服务或受限许可证数据；
- 修改对象 ID、schema version、bridge contract 或数据性质语义；
- 扩展到新的恒星 / 星系尺度，或宣称模型达到任务级精度；
- 发布应用商店包、创建付费资源或恢复旧技术栈。

### Never

- 把 `derived`、`simulated` 或 `fictional` 包装成 `observed`；
- 把当前结果用于真实飞行、任务设计或安全决策；
- 在帧循环中更新 Riverpod 或调用 Rust；
- 让领域 crate 依赖 Flutter 或平台框架；
- 提交密钥、真实用户数据、未许可素材、构建产物或工具缓存；
- 为了展示效果补造没有来源或性质的科学值。

## Acceptance Criteria

- [x] App 首屏直接展示中文太阳系地图和默认任务，不是营销落地页；
- [x] 用户可搜索中英文对象、查看详情并设置可达目的地；
- [x] 用户可比较三种路线并看到教学模型免责声明；
- [x] 用户可提交模拟时刻并得到时间相关位置、窗口与路线；
- [x] 用户可控制图层、开始 / 结束模拟导航并看到 HUD；
- [x] 对象、轨道参数组、字段、位置与路线保留可测试的数据性质；
- [x] Flutter / Rust contract 带 schema 与 catalog version；
- [x] `systemId` / `parentId` 支持当前太阳系层级并预留新系统；
- [x] Dart / Flutter 与 Rust 自动化测试覆盖核心流程；
- [x] Web 发行包包含应用、字体、Flutter/Dart 与 Rust 三方许可文本，并由门禁检查漂移；
- [x] 所有目标视口的浏览器或设备视觉回归完成且无重叠、裁切或空白画布；
- [ ] iOS 与 Android 完整原生工具链构建在可用的 Xcode / CocoaPods / Android SDK 环境中通过。

## Risks

- 教学近似容易被用户误读为实时精度；通过持续性质标记、方法说明和任务免责声明缓解。
- Flutter / Rust / WASM 增加生成和平台构建复杂度；通过锁定版本、统一脚本和 contract tests 缓解。
- 太阳系与恒星尺度差异巨大；通过 `systemId`、层级 ID 和未来独立尺度适配器缓解，当前不强行实现跨尺度画布。
- 科学来源会更新；目录必须版本化、记录访问时间，并通过离线工具重新校验，不能运行时静默变化。

## Open Questions

- 正式商店名称继续使用“天枢导航”还是保留仓库名“缺德导航”；
- 下一批真实数据优先接入版本化 SPICE 快照、JPL Horizons 预计算结果，还是行星表面地图；
- 3D 视图采用 Flutter 内嵌原生引擎还是独立场景层，需要在太阳系 2D MVP 完成性能基线后另做 ADR；
- 离线包的分发、签名、更新与版权策略尚未确定；
- 原生发布、签名和商店流水线尚未纳入本 MVP。
- Android release 当前保持未签名，不允许静默回退到 debug key。
