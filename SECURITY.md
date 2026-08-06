# 安全策略

## 支持版本

目前只支持 `main` 分支上的最新版本。项目是无账号、无后端的本地娱乐应用，不主动收集用户数据。

## 报告问题

请不要在公开 Issue 中发布密钥、个人信息或可利用的安全细节。仓库启用 GitHub Private Vulnerability Reporting 后，请使用 [私密安全报告入口](https://github.com/baicie/stellar-nav/security/advisories/new)，提供复现步骤、受影响平台、版本和最小日志。入口不可用时，请先开一个不含敏感细节的 Issue 请求维护者开启私密报告。收到报告后会确认影响范围，并在修复发布后更新说明。

## 开发安全要求

- 密钥只放在本地环境或 GitHub Actions secrets，不写入源码和构建产物；
- 依赖更新由 Dependabot 提议，并通过 `./scripts/verify.sh`；
- 真实天文数据接入前必须记录来源、许可、版本和校验方式；
- 不把模拟或虚构值展示为观测事实。
