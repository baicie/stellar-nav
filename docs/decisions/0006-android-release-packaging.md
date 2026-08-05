# ADR-0006: 以独立签名任务发布 Android APK 与 AAB

- 状态：Accepted
- 日期：2026-08-05

## 背景

首个公开版本需要可直接安装的 Android 包，同时为后续商店分发保留标准产物。当前仓库没有 Expo 账号令牌、EAS 项目和托管签名凭据，也不应为了单个平台发布而提交整棵生成的 `android` 目录。

## 决策

`vMAJOR.MINOR.PATCH` annotated tag 触发独立的 Android Release workflow。流水线先确认标签属于 `main` 完整历史，并让 `package.json`、Expo `version` 与版本化发布清单中的 Android `versionCode` 保持一致；发布清单要求版本与 `versionCode` 严格递增，且连续版本沿用同一证书指纹，防止侧载安装无法升级。若将来必须换钥匙，先新增独立的密钥迁移 ADR 和迁移策略，再修改此门禁。随后复跑完整质量门禁，使用 Expo Prebuild 在临时 runner 中生成原生工程，以持久 release keystore 构建通用 APK 和商店 AAB。签名文件与口令只存放在 GitHub Actions secrets，不写入源码、日志或构建缓存。

原生 Gradle 模板由一个带回归测试的 fail-closed 脚本配置：只有识别到 Expo SDK 57 当前模板时才替换默认 debug release 签名，模板变化时直接终止发布。构建后分别验证 APK 与 AAB 签名，并将签名证书与版本化发布清单中的公开 SHA-256 指纹比对；生成 SHA-256 校验文件和 GitHub build provenance 后，发布任务会在 runner 间传递后再次验证校验和，再创建 GitHub Release。手工触发只做签名构建演练，不创建 Release。

iOS 将来使用独立 job、独立凭据和独立产物名，不与 Android 签名或 runner 混用。

## 被否决的方案

### 使用 debug keystore 作为正式签名

debug key 可公开复用，无法建立可信升级链，不满足正式发布要求。

### 现在接入 EAS Build

EAS 是 Expo 官方推荐的托管构建方案，但 CI 非交互构建前必须先完成本地 EAS 初始化、首次构建和凭据创建。当前没有 Expo 账号凭据，强行加入只会得到无法执行的流水线。未来完成账号与凭据治理后可新增 ADR 迁移。

### 提交生成的 Android 原生目录

会放大 Expo SDK 升级差异和长期维护面；当前没有必须手改的原生功能，持续生成比长期持有原生目录更合适。

## 结果

Android 首版同时满足直接安装和商店分发需求，发布过程可重跑且不会泄漏签名信息。代价是 GitHub Runner 构建时间增加，Expo 模板升级可能要求同步更新并重新验证签名配置脚本。

## 依据

- https://docs.expo.dev/versions/v57.0.0/
- https://docs.expo.dev/build/building-on-ci/
- https://docs.expo.dev/build-reference/apk/
- https://docs.expo.dev/versions/v57.0.0/config/app/
- https://reactnative.dev/docs/signed-apk-android
