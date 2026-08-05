# ADR-0002: 将导航计算与 UI 状态隔离

- 状态：Accepted
- 日期：2026-08-05

## 背景

路线距离、时间、燃料和风险需要可复现、可测试，不能被 React 生命周期或平台 API 影响。UI 又需要在多个组件之间共享目的地、航线和导航状态。

## 决策

把纯领域模型放在 `src/core`，只使用 TypeScript 和标准库；把演示数据放在 `src/data`；把 Zustand store、React 组件和 Skia 适配放在上层。通过 `scripts/check-core-boundary.mjs` 阻止核心层导入 React、React Native、Expo、Skia 或 Zustand，并校验 `core`、`data`、`renderer`、`components` 的单向目录依赖。

## 结果

核心函数可以在 Node/Jest 中独立验证，未来可迁移到 Worker 或服务端而不改变 UI。渲染器只接收绘制所需的窄参数，不认识应用 store 或完整数据目录；跨层传递类型必须保持显式，不能用隐式全局变量绕过边界。
