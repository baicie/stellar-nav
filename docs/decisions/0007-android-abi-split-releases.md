# ADR-0007: 按 Android ABI 分发独立 APK 并保留 AAB

- 状态：Accepted
- 日期：2026-08-05
- 取代：ADR-0006

## 背景

v0.0.1 的通用 APK 同时携带多套架构的原生库，方便侧载但显著放大单个下载包。v0.0.2 仍需支持 GitHub Release 直接安装和未来的应用商店分发，同时必须维持既有签名升级链、可复现校验和构建来源证明。当前只发布 Android，不发布 iOS。

## 决策

Expo Prebuild 生成 Android 工程后，由带回归测试的 fail-closed 配置脚本向当前 SDK 57 Gradle 模板加入官方 `splits.abi` 配置。APK 构建启用拆包，设置 `universalApk false`；AAB 构建关闭 APK splits，使 React Native Gradle Plugin 能将同一组 `reactNativeArchitectures` 写入 AAB 的 NDK ABI filters。两个构建都只启用 `arm64-v8a`、`armeabi-v7a` 和 `x86_64`。若 Expo 模板不再符合已验证结构，配置脚本直接终止发布。

GitHub Release 固定提供三个侧载 APK、一个商店 AAB 和一个校验文件：

- `stellar-nav-android-arm64-v8a.apk`；
- `stellar-nav-android-armeabi-v7a.apk`；
- `stellar-nav-android-x86_64.apk`；
- `stellar-nav-android.aab`；
- `SHA256SUMS.txt`。

不再发布通用 APK，也不发布 32 位 x86 APK。流水线验证每个 APK 只包含文件名对应的 ABI、AAB 的原生库与原生调试符号只包含三个目标 ABI，并直接从二进制 manifest 核对应用 ID、`versionName` 和 `versionCode`。三个 APK 与 AAB 都使用发布清单锁定的同一证书签名；AAB 还必须通过 JAR 完整性检查且不得包含未签名条目。随后为二进制生成 SHA-256 校验值和 GitHub 构建来源证明。AAB 保留给应用商店，由商店按设备生成优化安装包，不作为直接下载的安装文件。

版本变更合入 `main` 且手工签名演练通过后，维护者在与 `origin/main` 一致的干净工作区运行 `./scripts/release.sh <version> --dry-run`。预检通过后再运行不带 `--dry-run` 的命令，脚本创建并推送 annotated tag，由标签触发正式发布。

本 ADR 取代 ADR-0006 的通用 APK 包装决策；ADR-0006 中的临时 Expo Prebuild、持久 release keystore、版本清单、签名校验和仅由标签创建 Release 等约束继续有效。

## 被否决的方案

### 继续发布通用 APK

用户只会运行一种 CPU 架构，通用包携带其余架构的原生库只会增加下载和存储成本。

### 只发布 AAB

AAB 适合应用商店动态交付，但不能由用户直接安装，无法满足 GitHub Release 侧载需求。

### 为每个 ABI 运行一套完整构建任务

可以得到相同的三个 APK，但会重复安装依赖、打包 JavaScript 和构建共享资源。一次 Gradle 构建生成 ABI splits 更直接，也更容易统一验证签名和版本。

### 同时发布通用 APK 与 ABI APK

会保留最大资产并增加用户选择歧义，无法实现缩减发布体积与资产面的目标。

## 结果

直接下载的 APK 不再携带无关架构的原生库，代价是用户必须选择与设备匹配的 ABI。现代真机通常选择 `arm64-v8a`，旧 32 位 ARM 设备选择 `armeabi-v7a`，x86_64 主要服务模拟器；32 位 x86 不在支持范围。应用商店仍使用 AAB，无需用户选择 ABI。

已发布的 tag 与资产保持不可变。工作流重跑若发现同名 Release，只接受名称与内容都和本次构建完全一致的五个资产，拒绝覆盖或增删。若拆包或应用本身出现阻断问题，停止分发受影响版本，在 `main` 回退问题改动，并以更高版本号和 `versionCode` 发布同一证书签名的修复；不使用旧的较低 `versionCode` 覆盖安装回滚。

## 依据

- https://docs.expo.dev/versions/v57.0.0/
- https://docs.expo.dev/versions/v57.0.0/config/app/
- https://developer.android.com/build/configure-apk-splits
- https://developer.android.com/guide/app-bundle
- https://reactnative.dev/docs/0.86/build-speed
- https://reactnative.dev/docs/0.86/signed-apk-android
