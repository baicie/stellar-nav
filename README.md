# 天枢导航 AstroNav

天枢导航是一款地图式太阳系科普 App：用用户熟悉的搜索、地图、路线比较、图层和时间轴交互，解释行星运动、转移窗口、通信时延与任务取舍；视觉表达偏科幻，数据口径保持克制。

> 当前路线、天体位置和风险指标都是教学模型输出，不可用于真实航天任务设计、飞行控制或安全决策。

## 当前 MVP

应用打开后直接进入太阳系导航地图，当前实现包括：

- “航线 / 太阳系”两种地图视图，以及平移、缩放、重置和对象点选；
- 中英文名称与别名搜索，天体和设施详情，以及字段级来源与数据性质标识；
- “最快到达 / 最省燃料 / 最低风险”三种确定性教学航线；
- 航时、距离、Delta-v、通信时延、风险、教学转移窗口和途经节点展示；
- 可回退、快进或返回现实时间的时间轴，松开滑块后重新计算位置与航线；
- 天体、轨道、航线、设施、通信、空间天气和风险图层；
- 带路线动画与阶段提示的模拟导航 HUD；
- 手机底部面板与宽屏左侧导航坞，以及中文无障碍名称。

内置目录当前包含 16 个对象：太阳、八大行星、月球、谷神星、冥王星、国际空间站教学轨道，以及 3 个明确标注为虚构的任务设施。太阳系是当前唯一可运行的数据域；`systemId` 和 `parentId` 已进入数据模型，为将来增加其他恒星系统和更大尺度的层级导航保留稳定边界。

以下能力尚未实现：实时 SPICE/JPL Horizons 星历、真实航天器遥测、Lambert 或多体高精度求解、完整 3D 视图、在线账号与后端、离线包下载管理。Rust 中的空间筛选与离线包清单解码目前是底层能力，不等于对应产品功能已经接通。

## 数据性质

每个对象、轨道参数组和科学字段都必须携带 `provenance`，界面同时用文字标出性质，不能只靠颜色区分。

| 类型 | 含义 | 当前示例 |
| --- | --- | --- |
| `observed` | 来自可追溯公开资料的观测或权威参数快照 | 行星半径、轨道周期 |
| `derived` | 由已声明输入和教学方法计算或整理 | J2000 简化轨道位置、ISS 静态教学轨道 |
| `simulated` | 为比较方案而生成的任务模拟结果 | 教学窗口评分、航时、Delta-v、风险、推荐分 |
| `fictional` | 服务于科幻叙事、现实中并不存在 | 阿尔忒弥斯月面基地、晨星火星港、地月 L1 中继站 |

目录来源包括 NASA NSSDC、NASA Solar System Exploration、NASA ISS 资料和 JPL Small-Body Database；具体 URL、访问时间、方法说明与字段性质保存在 [`data/solar_system_catalog.json`](data/solar_system_catalog.json)。自然天体与 ISS 的当前位置由简化 J2000 开普勒模型推导，不是实时观测；虚构设施的位置继续保持 `fictional`；教学窗口基于圆轨道霍曼目标相位和目录演示基准相位生成。路线把起终点和地月 L1 中继站组成显式航路图，使用内置载具 profile（航程、允许的行星域、支持模式和单边 Delta-v 上限）做确定性多目标搜索；航时、Delta-v、风险、通信和窗口都是科普代理成本，所有路线仍标记为 `simulated`，不可视为实测或任务推荐。

## 技术架构

- Flutter 3.44.8 / Dart 3.12.2 负责跨平台应用、响应式布局和无障碍语义；
- Riverpod 3.4.2 只保存搜索、选中对象、路线、时间和图层等低频产品状态；
- `CustomPainter` 与 Flutter `AnimationController` 负责地图和逐帧动画，帧进度不写入 Riverpod；
- Rust 1.96 workspace 负责目录、简化星历、转移窗口、路线和搜索；空间筛选与离线包格式保留为独立、可测试但尚未接入 App 的底层模块；
- `flutter_rust_bridge` 2.12.0 通过带 `schemaVersion` / `catalogVersion` 的 JSON envelope 暴露低频同步调用；
- Python 标准库工具在离线阶段校验目录结构、引用关系、数据性质和数值有效性，不进入 App 运行时。

```text
Flutter widgets / CustomPainter
            |
       Riverpod intent
            |
  NavigationRepository
            |
 flutter_rust_bridge
            |
       astro_engine
            |
  +---------+----------+-----------+
  | catalog | ephemeris| route/time| search/index/tile
  +---------+----------+-----------+
            |
 data/solar_system_catalog.json
            ^
 Python offline validator
```

核心取舍见 [`docs/decisions/`](docs/decisions/)，完整产品与验收边界见 [`docs/spec.md`](docs/spec.md)。旧 Expo / React Native / TypeScript / Skia / Zustand 实现已经弃用，不能作为当前架构继续演进。

## 本地开发

环境基线：

- Flutter `3.44.8`（包含 Dart `3.12.2`）；
- Rust `1.96.0`；
- `flutter_rust_bridge_codegen` `2.12.0`；
- Web 构建需要 `wasm-pack` `0.15.0`，以及带 `rust-src` 和 `wasm32-unknown-unknown` target 的 `nightly-2026-08-01`；
- iOS 或 Android 运行还需要对应的 Xcode / CocoaPods 或 Android SDK 工具链。
- Android release 不会回退到 debug 签名；正式分发前必须在受控环境配置独立发布密钥。

安装依赖并执行完整质量门禁：

```bash
flutter pub get
./scripts/verify.sh
```

运行 App：

```bash
flutter run -d chrome
flutter run -d <device-id>
```

常用的窄范围检查：

```bash
dart analyze lib test integration_test
flutter test
(cd native && cargo test --locked --workspace)
(cd native && cargo clippy --locked --workspace --all-targets -- -D warnings)
python3 -m unittest discover -s tools/data_pipeline/tests -p 'test_*.py'
python3 -m unittest discover -s tools/licenses/tests -p 'test_*.py'
python3 tools/licenses/generate_rust_licenses.py --check
```

仓库路径包含中文时，`flutter analyze` 在当前工具版本上可能因 LSP 消息解析失败；项目门禁使用 `dart analyze`。`./scripts/verify.sh` 是提交前的权威命令，它还会构建宿主 Rust 动态库并执行真实 bridge 冒烟测试，再检查格式、目录数据、桥接生成物、WebAssembly 和 Web 构建。

## Android 内测发布

Android GitHub prerelease 使用 `com.baicie.astro_nav`，与旧 Expo 应用 ID 不同。CI 在普通提交中使用临时测试证书构建三个 ABI release APK；只有受保护 `main` 上的 annotated tag 才能进入正式签名工作流，签名材料仅从 GitHub Actions Secrets 注入。

发布前先合并并同步 `main`，然后执行：

```bash
./scripts/release.sh 0.0.1-beta.0 --dry-run
./scripts/release.sh 0.0.1-beta.0
```

脚本拒绝脏工作区、非 `main` 分支、未推送提交、重复标签和不一致的版本元数据；实际打标签前会再次运行 `./scripts/verify.sh`。标签触发 Android release 工作流，生成 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三个独立签名 APK、SHA-256 校验文件和机器可读发布元数据，并创建 GitHub prerelease。详细安装、校验与回滚说明见 [`docs/releases/0.0.1-beta.0.md`](docs/releases/0.0.1-beta.0.md)。

## 目录

```text
lib/                         Flutter 应用、领域 DTO、导航功能与 FRB 生成代码
native/astro_engine/         面向 Flutter 的 Rust 桥接门面
native/crates/               可测试的 Rust 领域模块
data/                        版本化太阳系目录
tools/data_pipeline/         Python 离线目录校验工具
tools/licenses/              Rust 三方许可证生成与审计覆盖
tools/release/               Android 版本、签名和发布契约校验
test/                        Dart 单元与 Widget 测试
integration_test/            Flutter 集成测试入口
docs/spec.md                 产品、架构与验收规格
docs/decisions/              Architecture Decision Records
scripts/                     本地与 CI 共用的质量门禁
```

## 演进方向

下一阶段应先深化太阳系，而不是把不同尺度的数据硬塞进同一画布：接入版本锁定的公开星历快照、更可靠的轨道转移算法、行星表面数据、离线瓦片和 3D 场景。扩展到恒星或星系尺度时，应新增 `systemId` 数据域和尺度适配器，保留现有对象 ID、来源边界和桥接版本协议。

## 贡献与许可

提交改动前请阅读 [`CONTRIBUTING.md`](CONTRIBUTING.md) 和 [`AGENTS.md`](AGENTS.md)。代码使用 MIT License，见 [`LICENSE`](LICENSE)；离线中文字体采用 SIL Open Font License，见 [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)。Web 发行包还包含 Flutter notices，以及由锁定 Cargo 图和固定 nightly `build-std` 图共同生成的 [`rust-third-party-licenses.txt`](web/licenses/rust-third-party-licenses.txt)；数据源与其他视觉素材分别遵循其自身许可。
