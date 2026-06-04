# macOS 息屏/锁屏机制选型

## 决策

MVP 采用 **息屏 + 依赖系统"立即要求密码"** 实现锁屏效果。
息屏命令：`pmset displaysleepnow`。

## 方案对比

| 方案 | 实现 | 优点 | 缺点 | MVP |
|------|------|------|------|-----|
| `pmset displaysleepnow` | 关闭显示器 | 不需私有 API/特殊权限，稳定 | 需用户开"立即要密码"才等于锁屏 | **选用** |
| `CGSession -suspend` | 切到登录窗口 | 直接锁到登录界面 | 依赖 `/System/.../CGSession` 路径，行为受版本影响 | 备选 |
| IOKit `IOPMSleepSystem` | 整机睡眠 | 系统级 | 整机睡眠太重，非"仅锁屏" | 否 |
| 私有 `SACLockScreenImmediate` | 私有框架 | 直接锁屏 | 私有 API，签名/上架风险 | 否 |

## 选用方案的实现

息屏（Swift 调用子进程）：

```swift
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
task.arguments = ["displaysleepnow"]
try? task.run()
```

或更"硬"的锁屏（备选，写入 research 备查，非默认）：

```swift
// CGSession 方式，锁到登录窗口
let task = Process()
task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
task.arguments = ["-suspend"]
```

## 立即要密码的引导

`pmset displaysleepnow` 仅息屏。要达到"锁屏"安全效果，依赖系统设置：
**系统设置 → 锁定屏幕 → 在屏幕关闭或进入睡眠后立即要求输入密码**。

App 首次运行 / 事件日志中提示用户开启该设置。MVP 不强制编程修改该系统偏好
（涉及受保护的偏好域，需额外权限，超出 MVP）。

## 沙箱与权限

- 若 App 开启 App Sandbox：CoreBluetooth 需 entitlement
  `com.apple.security.device.bluetooth = true`。
- 用 `Process` 调 `/usr/bin/pmset` 在沙箱下会被限制；MVP 工程**不开启 App Sandbox**
  （本地自用工具，非上架），以保证 `pmset` 可执行。entitlements 文件保留但
  `App Sandbox` 关闭。这一点在 README 与 entitlements 注释中写明。
