# ADR-0004: 以 GitHub Actions 和性能预算作为合并门槛

- 状态：Accepted
- 日期：2026-08-05

## 背景

这是一个高性能的图一乐应用，视觉变化很容易带来包体、核心边界或跨平台回归。单靠本地手工检查无法稳定复现质量。

## 决策

在 Pull Request 和 `main` push 上运行 GitHub Actions：冻结安装依赖，执行格式检查、lint、TypeScript、核心边界、覆盖率测试、高危生产依赖审计、Expo Doctor、Web 导出和压缩 JavaScript 预算检查。质量预算固定为：生产模式动画目标 60 FPS；首屏演示数据同步解析低于 20 ms；Web 初始压缩 JavaScript 不超过 1.4 MB。CI 能直接定位每一项门禁，真实设备帧率仍在发布前手工抽查。Dependabot 每月更新 npm/pnpm 与 GitHub Actions 依赖。Issue/PR 模板要求说明测试、数据性质和视觉检查。

## 结果

合并前会验证行为、依赖边界和首屏 Web 产物，性能预算成为可见的工程约束。CI 运行需要 Expo/Skia 构建依赖和足够的缓存时间；真实设备帧率仍需在发布前手工抽查。
