# 更新日志

本文件记录当前 Flutter / Rust 代码线的用户可见变化。旧 Expo 0.0.x 实现已经停止演进，其历史仍可通过 Git 查看，但不再代表当前产品能力或发布流程。

## [Unreleased]

### Added

- 从地图首屏开始的“天枢导航”太阳系科普体验；
- 航线视图与太阳系视图，以及平移、缩放、重置、对象点选和分层显示；
- 中英文天体搜索、科学详情、来源说明和 `observed` / `derived` / `simulated` / `fictional` 标识；
- 太阳、八大行星、月球、谷神星、冥王星、ISS 教学轨道与虚构任务设施组成的版本化本地目录；
- 最快、最省燃料、最低风险三种教学路线及航时、Delta-v、通信时延、风险和教学窗口比较；
- 可调整 J2000 教学时刻的时间轴，以及带路线动画和阶段提示的模拟导航 HUD；
- Flutter 手机底部面板、宽屏左侧导航坞与中文无障碍语义；
- Rust workspace，拆分目录、简化星历、路线、搜索、空间索引、时间和离线包格式模块；
- 通过 `flutter_rust_bridge` 暴露的版本化 JSON contract；
- Python 离线目录校验器、Dart/Flutter 测试、Rust contract 测试和统一验证入口。

### Changed

- 以 Flutter 3.44、Riverpod、CustomPainter、Rust 和 Python 离线工具链重建项目架构；
- 产品范围从旧版远星际演示收敛为“先把太阳系讲清楚”的地图式科普 MVP；
- 所有连续动画改为渲染层本地驱动，Riverpod 与 Rust 只处理低频状态和计算请求；
- 数据模型加入 `systemId`、`parentId`、轨道级 provenance、catalog version 和 schema version，为未来恒星系统扩展保留兼容边界。

### Removed

- Expo、React Native、TypeScript、Skia、Reanimated、Zustand 和 pnpm 实现；
- 旧 Android 标签发布脚本、旧 Expo CI 与对应发布文档；
- 旧版把恒星级虚构路线作为首屏主流程的产品逻辑。

### Known limitations

- 当前星历和路线均为确定性教学近似，不是 SPICE、Horizons 或飞行任务级结果；
- 当前只有太阳系二维示意地图，真实 3D、行星表面导航和其他恒星系统尚未实现；
- 空间天气、风险区域、离线包与空间索引仍有示意或底层预留成分，尚非完整在线产品能力。
