# 更新日志

## 0.0.2 - 2026-08-05

- Android 侧载包改为 `arm64-v8a`、`armeabi-v7a` 与 `x86_64` 三个独立 ABI APK，移除通用 APK，避免单个安装包携带多套原生库；
- 保留用于应用商店分发的 AAB，并继续发布 `SHA256SUMS.txt` 与构建来源证明；
- 增加本地发布脚本，在创建并推送 annotated tag 前校验分支、工作区、远端状态和版本元数据；
- 扩展发布配置与发布脚本的回归测试。

## 0.0.1 - 2026-08-05

- 初始化 Expo SDK 57 星图应用；
- 增加确定性路线计算、格式化和数据性质边界；
- 增加 Skia 星图、Reanimated 航行演示、路线选择和目的地弹层；
- 增加核心/状态/关键屏幕测试与 Web 体积检查；
- 增加原生深色系统界面配置；
- 隔离 Web CanvasKit 与原生入口，并增加 Android bundle 构建门禁；
- 增加 GitHub Actions、Dependabot 和协作模板；
- 增加 Android APK/AAB 签名构建、产物校验和标签发布流水线。
