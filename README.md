# 缺德导航

一个高性能、带点坏笑的星际导航模拟器。它把真实天文对象、确定性的演示航线和 GPU 星图放在同一块屏幕里，适合拿来图一乐，不是航天飞行控制软件。

## 当前目标

首版 MVP 直接进入 2.5D 星图，支持：

- 从地球选择仙女座星系、比邻星、天狼星或 TRAPPIST-1；
- 比较推荐、最快、避开黑洞三条演示航线；
- 查看距离、预计耗时、燃料、风险和数据性质；
- 启动/结束航行，观察飞船沿航线推进；
- 在手机和 Web 预览中保持可访问、可读和不依赖后端。

第一版明确不做账号、在线天文 API、完整 Gaia 数据、真实轨道积分、支付和遥测。

## 技术栈

- Expo SDK 57.0.10、React Native 0.86.2、React 19、TypeScript 6；
- React Native Skia 绘制星场、银河带、航线和飞船；
- Reanimated shared values 驱动连续动画；
- Zustand 管理低频导航状态；
- Jest、jest-expo 和 React Native Testing Library 做领域与交互测试；
- pnpm 10 管理依赖。

核心领域代码位于 `src/core`，不依赖 React、React Native、Expo、Skia 或 Zustand，可单独测试且结果确定。

## 开始使用

环境要求：Node.js 22.13-24、pnpm 10。Expo SDK 57 的 CI 基线使用 Node.js 24。

```bash
pnpm install --frozen-lockfile
pnpm dev
```

常用命令：

```bash
pnpm web                 # Web 预览
pnpm ios                 # iOS 模拟器或真机
pnpm android             # Android 模拟器或真机
pnpm test                # 测试
pnpm verify              # 格式、lint、类型、边界、测试、审计、Doctor、Android/Web 构建
```

## Android 发布

`vMAJOR.MINOR.PATCH` annotated tag 会触发 `Android Release` workflow。流水线复跑全部质量门禁，再生成并验证以下 Android 产物：

- `stellar-nav-android-arm64-v8a.apk`：绝大多数现代 Android 真机；
- `stellar-nav-android-armeabi-v7a.apk`：仍使用 32 位 ARM 的旧设备；
- `stellar-nav-android-x86_64.apk`：x86_64 模拟器或设备；
- `stellar-nav-android.aab`：用于应用商店提交，不可直接安装；
- `SHA256SUMS.txt`：三个 APK 与 AAB 的 SHA-256 校验值。

每个 APK 只包含对应 ABI 的原生库，不发布通用 APK，也不提供 32 位 x86 APK。发布页同时保留 GitHub 构建来源证明。当前仅发布 Android，不发布 iOS 包。

版本必须同时写入 `package.json`、`app.json` 和 `docs/releases/manifest.json`，Android `versionCode` 每次发布严格递增，发布证书公开指纹也由该清单锁定。正式签名使用仓库 Actions secrets 中的 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS` 与 `ANDROID_KEY_PASSWORD`，签名文件不会进入 Git；维护者必须保留受保护的离线备份，丢失密钥后无法继续覆盖安装升级。

从 `main` 手工运行 workflow 只做签名构建演练，不创建 GitHub Release。演练通过并合入版本变更后，在与 `origin/main` 一致的干净 `main` 上使用本地脚本先预检、再发布：

```bash
./scripts/release.sh 0.0.2 --dry-run
./scripts/release.sh 0.0.2
```

脚本会验证版本元数据，创建并推送 annotated tag；也可用 `--message` 自定义标签消息。已发布的 tag 和资产不应移动或覆盖。若版本出现阻断问题，应停止分发该版本、在 `main` 回退问题改动，并以更高的版本号和 `versionCode` 发布修复；Android 不支持用较低 `versionCode` 的旧包直接覆盖回滚。

v0.0.2 发布说明见 [`docs/releases/0.0.2.md`](docs/releases/0.0.2.md)，ABI 拆包决策见 [`ADR-0007`](docs/decisions/0007-android-abi-split-releases.md)。v0.0.1 的历史发布方案保留在 [`ADR-0006`](docs/decisions/0006-android-release-packaging.md)。

## 目录结构

```text
src/app/                 屏幕组合、应用状态和动效偏好
src/components/          导航栏、航路栏、弹层和底部控制
src/core/                平台无关的路线计算、格式化和数据性质
src/data/                版本化的演示天体、飞船与航线
src/design/              颜色、间距、字体和圆角令牌
src/renderer/            Skia 星图渲染适配层
docs/decisions/          架构决策记录（含已取代历史）
scripts/                 核心依赖边界和 Web 体积检查
```

## 数据边界

界面会显式区分四种数据性质：`observed`（观测）、`derived`（由观测归一化推导）、`simulated`（演示模拟）和 `fictional`（虚构）。MVP 的距离来自小型版本化演示星表，路线、时间、燃料和风险来自确定性模拟模型；它们不会伪装成实时航天数据。

## 性能约束

星图绘制放在 Skia，连续航行动画只更新 Reanimated shared values，不按帧写 React 或 Zustand。性能预算是生产模式目标 60 FPS、首屏演示数据同步解析低于 20 ms、Web 初始压缩 JavaScript 不超过 1.4 MB。安装阶段会把与当前 Skia 版本匹配的 CanvasKit WASM 生成到本地 `public` 目录，Web 运行时不依赖第三方 CDN。CI 会检查核心依赖边界、Web 体积预算、高危依赖审计，并运行 Expo Doctor。

## 设计与演进

产品规格见 [`docs/spec.md`](docs/spec.md)，关键取舍见 [`docs/decisions/`](docs/decisions/)。后续若接入 Gaia/SIMBAD/NASA 数据，需要单独完成来源许可、版本锁定、质量校验和展示口径评审。

## 贡献

请先阅读 [`CONTRIBUTING.md`](CONTRIBUTING.md)。行为变更必须补测试，并在提交前运行 `pnpm verify`。

## 许可证

本项目代码以 MIT License 发布，见 [`LICENSE`](LICENSE)；许可证文件同时保留 Expo 模板的上游版权声明。第三方字体和依赖遵循各自许可证。
