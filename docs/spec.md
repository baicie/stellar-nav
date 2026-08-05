# Spec: 缺德导航 / Interstellar Navigator MVP

## Assumptions

1. 第一版是 iOS、Android 和 Web 可预览的移动端应用，不接账号系统。
2. 产品定位是基于真实天文对象的娱乐型导航模拟器，不是航天飞行控制软件。
3. MVP 使用内置、版本化的小型演示数据集；官方天文数据 ETL 和 Rust 后端只保留清晰边界，不在本次初始化中伪造。
4. 默认语言为简体中文，目标设备为近三年的主流手机和现代浏览器。
5. 用户要求一次完成初始化，因此在不扩大产品范围的前提下，本文中的假设视为本轮实施基线。

## Objective

构建一个真正可玩的 2.5D 星际导航 MVP。用户打开应用后直接进入星图，可以从地球选择目的地、比较多条路线、辨认科学事实与虚构设定的边界，并启动一段航行演示。

核心用户流程：

1. 在星图或搜索入口选择目的地。
2. 在“推荐、最快、避开黑洞”等路线中切换。
3. 查看距离、预计耗时、燃料和风险，以及数据性质。
4. 启动导航，观察飞船沿路线推进并可结束航行。

非目标：真实轨道积分、完整 Gaia 数据、在线账号、支付、社交、LLM 实时算路、微服务和自研原生渲染器。

## Tech Stack

- Expo SDK 57.0.10 + React Native 0.86.2 + React 19.2.3 + TypeScript 6.0.3。
- React Native Skia 负责星图、航线和飞船的 GPU 绘制。
- Reanimated 负责不依赖 React 重渲染的连续动画。
- Zustand 只管理跨组件的低频产品状态。
- Jest + `jest-expo` 负责领域核心和原生组件测试；React Native Testing Library 负责关键组件行为。
- pnpm 管理依赖；核心逻辑位于无 React/Expo/Skia 依赖的独立源码边界。

技术依据：

- https://docs.expo.dev/versions/v57.0.0/
- https://docs.expo.dev/versions/v57.0.0/sdk/skia/
- https://docs.expo.dev/versions/v57.0.0/sdk/reanimated/
- https://reactnative.dev/docs/performance
- https://shopify.github.io/react-native-skia/docs/getting-started/web/
- https://docs.swmansion.com/react-native-reanimated/docs/fundamentals/getting-started/

## Commands

```bash
pnpm install --frozen-lockfile
pnpm dev
pnpm ios
pnpm android
pnpm web
pnpm lint
pnpm typecheck
pnpm test
pnpm test:coverage
pnpm build:web
pnpm verify
```

## Project Structure

```text
src/
  app/                 应用组合、状态与屏幕
  components/          可复用 React Native 组件
  core/                无 UI 框架依赖的导航领域模型和算法
  data/                版本化演示天体与路线数据
  design/              颜色、排版、间距和动效令牌
  renderer/            Skia 星图投影与绘制适配层
assets/                 字体、位图和应用图标
tests/                  测试环境与跨模块测试
docs/decisions/         架构决策记录
.github/                CI、依赖更新和协作模板
```

依赖方向：`app -> components/renderer/data/core`，`components -> renderer/data/core`，`renderer -> core/design`，`data -> core`。`core` 只能使用 TypeScript 和标准库，不能导入 React、React Native、Expo、Skia 或 Zustand。

## Code Style

使用显式领域类型、纯函数和语义化命名；UI 状态与领域计算分开。

```ts
export function estimateTravelTime(distanceLy: number, cruiseSpeedC: number): number {
  if (distanceLy < 0 || cruiseSpeedC <= 0) {
    throw new RangeError('Travel inputs must be positive');
  }

  return distanceLy / cruiseSpeedC;
}
```

- React 组件文件使用 PascalCase，其他模块文件使用 kebab-case；组件和类型使用 PascalCase，函数和变量使用 camelCase。
- 禁止 `any`、隐式副作用、未解释的魔法数字和用颜色作为唯一状态提示。
- 注释只解释非显而易见的原因或性能约束。

## Testing Strategy

- 领域核心：路线排名、耗时/燃料估算、风险过滤和数据来源边界均以测试先行。
- 组件：覆盖路线切换、目的地选择、导航开始/结束和无障碍名称。
- 静态质量门：ESLint、Prettier、TypeScript strict、依赖审计、Expo Doctor。
- 运行时：在 390x844、320x568 和宽屏 Web 视口检查无重叠、无空白画布、无控制台错误。
- 性能：生产模式目标 60 FPS；动画状态不得按帧写入 React/Zustand；首屏演示数据同步解析预算低于 20 ms；Web 初始压缩资源预算记录并由 CI 监控。

## Boundaries

Always:

- 在提交前运行 `pnpm verify`，为所有领域行为添加测试。
- 在 UI 中标注 `observed`、`derived`、`simulated`、`fictional` 数据性质。
- 保持 `core` 可独立测试、确定性和平台无关。
- 支持键盘/屏幕阅读器，并尊重“减少动态效果”设置。

Ask first:

- 引入在线 API、账号、数据库、遥测或会收集用户数据的 SDK。
- 改变天文数据口径、加入收费能力或上传用户内容。
- 发布到应用商店或创建付费云资源。

Never:

- 提交密钥、构建产物、真实用户数据或未经许可的受限素材。
- 把模拟或虚构值展示成观测事实。
- 让 LLM 参与核心数值计算或在渲染帧循环中触发 React 状态更新。

## Success Criteria

- [ ] 全新克隆后可用文档中的命令安装、检查并启动。
- [ ] 首屏呈现与设计参考一致的全屏星图、发光航线、目的地层级、路线方案和主导航命令。
- [ ] 用户可以选择至少 3 个目的地、切换至少 3 条路线，并启动/停止航行。
- [ ] 路线的距离、耗时、燃料和风险由确定性领域函数计算，测试覆盖成功与非法输入。
- [ ] 所有可交互元素有可访问名称，320 px 宽度无文字溢出或控件重叠。
- [ ] 动画由 Skia/Reanimated 驱动，按帧过程不进入 React/Zustand 状态。
- [ ] CI 在 pull request 和 main push 上执行格式、lint、类型、测试、覆盖率、构建、Expo Doctor 和高危依赖审计。
- [ ] 关键技术选择、数据真实性边界、渲染性能和演进路线均有 Accepted ADR。
- [ ] GitHub 仓库、README、贡献说明、Issue/PR 模板、Dependabot 和 GitHub Project 已创建并可访问。

## Open Questions

- 正式产品名、图标和应用商店身份在品牌阶段确定；当前工作名为“缺德导航”。
- 真实 Gaia/SIMBAD/NASA 数据接入需在后续数据管线里单独做来源许可、版本和质量验收。
