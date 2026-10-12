# PublicWorks CI

iOS App（查自己 UID 的公开作品）的云端构建与 UI 回归测试仓库。

- `Sources/` — App 源码（SwiftUI，iOS 15+）
- `UITests/` — XCUITest 全量回归（配置校验 → TLS 查询 → 并发防护 → 401 → 清除数据）
- `mock/` — FastAPI Mock 服务（虚构数据）
- `tools/generate_cert.py` — 本地自签证书生成
- `project.yml` — XcodeGen 工程描述
- `.github/workflows/ios-ci.yml` — GitHub Actions macOS 流水线

push 到 main 即自动：云端 Mac 起 Mock → 生成工程 → 模拟器跑 UI 测试 → 上传 xcresult + 日志。

Demo 用途，Token 为虚构测试值，不含任何真实凭据。
