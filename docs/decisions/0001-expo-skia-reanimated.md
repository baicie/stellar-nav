# ADR-0001: 采用 Expo、Skia 与 Reanimated 的移动优先渲染栈

- 状态：Accepted
- 日期：2026-08-05

## 背景

首版要在 iOS、Android 和 Web 预览中快速交付，同时让星图、发光航线和飞船动画保持流畅。纯 React Native View 逐点绘制会增加层级和重渲染成本；自研原生渲染器又会显著扩大初始化范围。

## 决策

使用 Expo SDK 57 + React Native 0.86 作为应用壳，使用 React Native Skia 绘制星场和航线，使用 Reanimated shared values 驱动连续动画，使用 Zustand 仅存放低频产品状态。遵循 Expo SDK 57 的官方版本组合和 Metro Web 预览路径。Web 平台模块先完成 `LoadSkiaWeb()` 再动态导入 App；通用原生入口只解析无 CanvasKit 依赖的实现，避免把 Web/Node 模块加入 Android 或 iOS JavaScript 依赖图。`postinstall` 使用 Skia 自带的 `setup-skia-web` 把匹配版本的 CanvasKit WASM 放入本地 `public`，避免运行时依赖第三方 CDN；Android export 仅作为 Metro 回归检查，不作为 OTA 或分发产物。

## 结果

星图绘制集中在 GPU 友好的 Canvas，航行动画不触发 React/Zustand 每帧更新，且保留 Expo 的跨平台开发速度。代价是需要维护 Skia Web/Jest mock，并在未来加入更复杂的手势或原生能力时核对平台差异。

## 依据

- https://docs.expo.dev/versions/v57.0.0/
- https://docs.expo.dev/versions/v57.0.0/sdk/skia/
- https://docs.expo.dev/versions/v57.0.0/sdk/reanimated/
- https://shopify.github.io/react-native-skia/docs/getting-started/web/

## 备选方案

- 纯 React Native View：实现简单，但星场和路径层级更重；
- Three.js：适合真正 3D，但首版 2.5D 星图会引入不必要的场景与资产复杂度；
- 自定义 Rust/原生渲染器：潜在性能高，但超出 MVP 的风险和维护预算。
