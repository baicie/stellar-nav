# 贡献指南

## 开始前

请先阅读 [`docs/spec.md`](docs/spec.md) 和 [`docs/decisions/`](docs/decisions/)，确认改动仍属于娱乐型星际导航 MVP 的范围。新增在线服务、账号、遥测、真实数据管线或收费能力前，需要先提出设计讨论。

## 本地流程

```bash
pnpm install --frozen-lockfile
pnpm verify
```

行为变更遵循测试先行：先为 `src/core` 或用户流程添加失败用例，再实现最小改动，最后运行完整验证。组件测试应覆盖交互和无障碍名称；动画不得在每帧更新 React 或 Zustand 状态。

## 提交与 Pull Request

- 分支使用 `codex/` 或 `feature/` 前缀，保持一次 PR 一个清晰目标；
- 提交信息使用简短的 Conventional Commits 风格，例如 `feat: add route provenance labels`；
- PR 描述说明行为变化、测试命令、数据性质和视觉检查结果；
- 不提交密钥、构建产物、用户数据或未经许可的素材；
- 所有 CI 检查通过后再请求合并。

## 代码约定

代码标识符和文件名使用英文，面向用户的文案使用简体中文。`src/core` 保持平台无关、确定性和无 UI 依赖。复杂性能约束用短注释说明原因，避免重复描述代码表面行为。
