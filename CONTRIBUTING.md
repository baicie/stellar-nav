# 贡献指南

天枢导航当前处于 Flutter / Rust 全新代码线。开始改动前请先阅读 [`docs/spec.md`](docs/spec.md)、[`AGENTS.md`](AGENTS.md) 和相关 [`docs/decisions/`](docs/decisions/)；不要从 Git 历史中恢复旧 Expo 架构或旧产品逻辑。

## 环境准备

建议使用与仓库基线一致的 Flutter 3.44.8、Dart 3.12.2、Rust 1.96.0、`flutter_rust_bridge_codegen` 2.12.0 和 `wasm-pack` 0.15.0。

```bash
flutter pub get
./scripts/verify.sh
```

`./scripts/verify.sh` 是本地与 CI 共享的权威门禁。它覆盖 Dart 格式与分析、Flutter 测试、Rust 格式 / Clippy / 测试、数据目录校验、桥接生成物、WebAssembly 运行时契约、Rust 三方许可证漂移，以及 Web 构建与发行许可载荷。仓库路径包含中文时请使用脚本内的 `dart analyze`，不要把 `flutter analyze` 的 LSP 解析崩溃误判为源码问题。

门禁会先构建当前宿主平台的 Rust 动态库，让标准 Flutter 测试实际初始化 FRB。Android release 不使用 debug 签名；需要分发原生包时，在外部受控环境配置发布密钥，不要把 `key.properties` 或密钥材料提交到仓库。

开发时可以先运行窄范围命令：

```bash
flutter test test/features/navigation/navigator_controller_test.dart
(cd native && cargo test -p route_engine)
python3 -m unittest discover -s tools/data_pipeline/tests -p 'test_*.py'
```

## 改动落点

| 改动 | 主要位置 | 约束 |
| --- | --- | --- |
| 页面、控件、无障碍 | `lib/src/features/`、`lib/src/widgets/` | 中文文案；手机和宽屏都可用 |
| UI 状态与意图 | `navigator_controller.dart` | 只保存低频产品状态 |
| Flutter 到 Rust 的调用 | `navigation_repository.dart` | Widget 不直接依赖 FRB 生成 API |
| 领域数据契约 | `lib/src/domain/`、`native/crates/astro_core/` | Dart / Rust 字段与 JSON 命名保持一致 |
| 星历、路线与搜索逻辑 | `native/crates/*` | 确定性、平台无关、无 Flutter 依赖 |
| 桥接门面 | `native/astro_engine/` | 版本化 envelope；避免逐帧调用 |
| 科学目录 | `data/solar_system_catalog.json` | 来源、性质、层级、版本全部可校验 |
| 离线数据工具 | `tools/data_pipeline/` | 只使用离线工具链，不进入 App 运行时 |
| 许可证工具 | `tools/licenses/` | 从锁定的 WASM 依赖图生成；缺失正文必须精确版本审计 |
| 品牌图标 | `tools/generate_brand_icons.py` | 从同一几何标识生成 Web、Android、iOS 图标 |

不要手改以下生成文件：

- `lib/src/rust/frb_generated*.dart`
- `native/astro_engine/src/frb_generated.rs`
- `web/pkg/*`
- `web/licenses/rust-third-party-licenses.txt`

桥接 API 变化后运行配置驱动的生成命令，并让完整验证检查漂移：

```bash
flutter_rust_bridge_codegen generate
python3 tools/licenses/generate_rust_licenses.py
```

品牌标识调整后，用安装了 Pillow 的 Python 环境重新生成全部平台图标：

```bash
python3 tools/generate_brand_icons.py
```

## 数据改动

任何数字都必须先决定其数据性质，再决定展示方式。

- `observed`：引用可访问的公开来源，并记录访问时间；
- `derived`：写明输入、方法与局限，不能称为实时观测；
- `simulated`：标注模型版本、假设和教学免责声明；
- `fictional`：对象与字段都保持虚构标识，不能借真实机构名暗示已存在。

修改目录后至少运行：

```bash
python3 -m unittest discover -s tools/data_pipeline/tests -p 'test_*.py'
(cd native && cargo test -p astro_core -p astro_engine)
```

新增数据系统时保留现有 ID，以新的 `systemId` 建立命名空间，并用 `parentId` 表达层级。不要为了远期恒星或星系尺度而破坏当前 `sol/...` 对象引用。

## 状态与动画

Riverpod 适合搜索词、选中对象、提交后的模拟时间、路线策略、图层开关和导航开始 / 结束。镜头插值、星光呼吸、航行器进度等逐帧值必须停留在 `AnimationController`、`CustomPainter` 或其他渲染本地对象中；帧循环不得写 Riverpod，也不得跨 `flutter_rust_bridge` 调用 Rust。

如果改动 Rust 计算，先在对应 crate 增加失败用例；如果改动用户流程，增加 Widget 测试并断言中文无障碍名称。地图或布局改动还应在 320 x 568、390 x 844、平板和宽屏视口检查空白画布、文字截断和控件遮挡。

## 架构与范围变更

以下改动需要先讨论并新增或更新 ADR：

- 更换 UI、状态、渲染、桥接或核心计算技术；
- 修改 bridge schema、catalog schema、对象 ID 或数据性质语义；
- 接入在线星历、账号、后端、数据库、遥测、用户数据或付费服务；
- 引入完整 3D 引擎、运行时 Python、云资源或新的许可证负担。

规格变化先更新 [`docs/spec.md`](docs/spec.md)，再改实现。Rust 低层占位模块不应在 README 或产品文案中被描述为已完成的用户功能。

## 提交与 Pull Request

- 分支使用 `codex/` 或 `feature/` 前缀，一次 PR 只解决一个清晰目标；
- 提交信息采用简短 Conventional Commits，例如 `feat(route): add Venus teaching transfer`；
- PR 描述写明用户行为、数据性质、模型局限、测试命令和视觉检查视口；
- 不提交密钥、真实用户数据、构建产物、未授权素材或本地工具缓存；
- 提交前运行 `./scripts/verify.sh`，质量门禁全部通过后再请求合并。

推荐的 PR 自检项：

- [ ] 功能仍属于太阳系科普 MVP，或已经有批准的范围 ADR；
- [ ] 科学值、推导值、模拟值和虚构值没有混淆；
- [ ] 行为和 contract 变化都有测试；
- [ ] 中文文案、无障碍名称和响应式布局已检查；
- [ ] 文档与实现同步；
- [ ] `./scripts/verify.sh` 通过。
