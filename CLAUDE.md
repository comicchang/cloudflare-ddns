# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 常用命令

```bash
# 构建
cargo build --release

# 构建并立即运行（本地开发用）
./start-sync.sh [args]

# 运行测试
cargo test

# 运行单个测试
cargo test <test_name>

# 检查代码（不生成产物）
cargo check
```

## 架构概览

这是 [timothyjmiller/cloudflare-ddns](https://github.com/timothyjmiller/cloudflare-ddns) 的 Rust 实现 fork，基于上游 v2.1.0，加入了三项本地定制（见 commit `74fd7db`）。

### 运行模式

程序有两套互斥的配置模式：

- **环境变量模式**（`CLOUDFLARE_API_TOKEN` 存在时）：通过环境变量配置，功能完整
- **Legacy JSON 模式**（`CLOUDFLARE_API_TOKEN` 不存在时）：读取 `config.json` 文件，保持对旧版配置的向后兼容

`AppConfig.legacy_mode` 字段标记当前模式，`updater.rs` 中以此分支处理两套更新逻辑。

### 核心模块

| 模块 | 职责 |
|------|------|
| `main.rs` | 入口、CLI 参数解析、调度循环（`@every Nm` / cron 表达式）、信号处理 |
| `config.rs` | 配置加载，支持两种模式；`AppConfig` 是统一的运行时配置结构 |
| `updater.rs` | 单次更新周期 `update_once()`，协调 IP 检测 → DNS/WAF 更新 → 通知 |
| `cloudflare.rs` | Cloudflare REST API 封装（`CloudflareHandle`），处理 DNS record 和 WAF list |
| `provider.rs` | IP 检测策略，支持 `cloudflare.trace`、`cloudflare.doh`、`ipify`、`local`、自定义 URL、静态 IP |
| `cf_ip_filter.rs` | Cloudflare anycast IP 段缓存（`CachedCloudflareFilter`），防止将 CF IP 写入 DNS |
| `notifier.rs` | Shoutrrr 通知、Healthchecks.io / Uptime Kuma 心跳 |
| `pp.rs` | 格式化输出（emoji / quiet 模式开关） |
| `domain.rs` | FQDN 构造工具函数 |

### 调度逻辑

`main.rs` 中的主循环：解析 `UPDATE_CRON`（支持 `@every 5m` 等速记，以及标准 cron 表达式）→ 在 `update_on_start` 为 true 时立即执行一次 → 按 cron 周期循环调用 `updater::update_once()` → 收到 SIGINT/SIGTERM 时优雅退出（`delete_on_stop` 控制是否清除 DNS 记录）。

### 本地三项定制

相对上游的修改（commit `74fd7db`）集中在 `src/main.rs` 和 `src/config.rs`，以及新增 `start-sync.sh`。修改上游行为前，需对比这些改动，避免合并冲突。

## 配置参考

核心环境变量：

```
CLOUDFLARE_API_TOKEN   # 必填（env 模式）
DOMAINS                # 逗号分隔域名
IP4_PROVIDER           # 默认 ipify
IP6_PROVIDER           # 默认 cloudflare.trace
UPDATE_CRON            # 默认 @every 5m
UPDATE_ON_START        # 默认 true
```

Legacy JSON 配置路径默认 `./config.json`，可通过 `CONFIG_PATH` 环境变量修改目录。
