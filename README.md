# Lumina iOS — 网页套壳 IPA 工程

Lumina（纯聊天）的 iOS 壳：WKWebView 全屏加载线上网页，自带持久化存储——**登录一次，长期保留**（localStorage 不随启动清空，除非卸载 App）。

仓库结构：

```
lumina-ios/
├── Lumina/                  # Swift 源码 + 资源
│   ├── AppDelegate.swift
│   ├── ViewController.swift # WKWebView 壳（持久数据仓库 + 断网重试）
│   ├── Info.plist           # 由 xcodegen 生成到工程里
│   └── Assets.xcassets/     # App 图标
├── project.yml              # xcodegen 工程描述（不要手写 pbxproj）
└── .github/workflows/ios.yml # GitHub Actions：云端 Mac 自动编译未签名 IPA
```

## 为什么是"未签名 IPA"

GitHub Actions 的 Mac 机器上**没有你的苹果证书**，所以云端只负责编译；签名这一步由你电脑上的 **Sideloadly** 用你的免费 Apple ID 完成。这是 Windows 用户装 IPA 的标准路径。

---

## 完整安装流程（全程 Windows，零付费）

### 第 1～2 步：已完成 ✅

仓库已建好、IPA 已编译并下载到本地：

- 仓库：<https://github.com/Weslie-arch/lumina-chat>（Public，macOS 编译分钟免费）
- 产物：`Lumina.ipa`（工作区根目录，约 157 KB）

**直接跳到第 3 步。**

以后要重新出包（只有改图标 / URL / 壳代码才需要）：push 一次，Actions 自动跑，约 1.5 分钟出包。

```bash
gh run list --limit 1            # 拿到 run id
gh run watch <id> --exit-status  # 等它跑完
gh run download <id> --dir ipa-out
```

> 构建机是 `macos-15`（Xcode 16）。别改回 `macos-14`——那边是 Xcode 15.4，读不了 xcodegen 生成的工程格式 77，会报 "future Xcode project file format"。

### 第 3 步：iPhone 开启开发者模式（一次性）

> 设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启

### 第 4 步：Sideloadly 签名安装

1. 电脑装 [Sideloadly](https://sideloadly.io)
2. 装非商店版 [iTunes](https://www.apple.com/itunes/)（带 USB 驱动；如果 Sideloadly 提示缺驱动再装）
3. USB 连手机，手机点「信任此电脑」
4. Sideloadly 里：拖入 `Lumina-unsigned.ipa` → 填你的 Apple ID（建议小号）→ 选设备 → **Start**
5. 出 2FA 就在手机上批准并输 6 位码
6. 手机上：设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID 证书
7. 主屏出现 **Lumina**，打开即用

---

## 免费账号的三条规矩

| 限制 | 说明 | 对策 |
|---|---|---|
| 7 天过期 | 免费证书 7 天有效，到期 App 闪退 | Sideloadly 设置里勾 **Wi-Fi 自动刷新**（手机电脑同一路由器、电脑开机，自动续期，基本无感） |
| 最多 3 个 | 同一设备同时最多 3 个侧载 App | 卸载不用的 |
| 每周 10 个 App ID | 一般碰不到 | 忽略 |

## 改了网页怎么更新？

线上网页改了**不需要重新打 IPA**（壳加载的就是线上地址，打开就是最新版）。
只有改壳本身（图标、启动屏、URL）才需要 push 后重新跑 Actions、重新签名安装。

## 登录能保留多久？

- 正常使用：**一直有效**。会话存在 App 的持久存储里，关掉重开、重启手机都在
- 卸载 App：本地数据清空，需要重新登录（云端账号和消息不受影响）
- 长期不登录：refresh 凭据可能过期，重登一次即可，账号数据都在云端
