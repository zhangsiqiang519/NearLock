# macOS 息屏/锁屏机制选型

## 决策（经实测迭代后的最终结论）

采用 **`SACLockScreenImmediate`（login.framework 私有符号，dlopen 调用）** 真正锁屏，
osascript 与 pmset 息屏作降级兜底。

**迭代过程（重要教训）**：
1. 初版用 `pmset displaysleepnow` 仅息屏 → 实测用户机 `screenLock delay=300s`，
   息屏后 5 分钟宽限期内晃鼠标即回桌面，等于没锁。
2. 改 osascript 发 Ctrl+Cmd+Q → 实测仍无效。根因：开发版 App 是 **ad-hoc 签名**
   （`TeamIdentifier=not set`），发送系统按键被 TCC 静默拦截，连授权弹窗都不弹，
   且 osascript 退出码仍为 0，导致"看起来没反应"。
3. 改 `SACLockScreenImmediate` → **独立脚本实测返回 0、屏幕真正锁定**。
   纯进程内调用，不发按键、不碰其他进程，**无需辅助功能权限**，绕开 ad-hoc 签名的 TCC 拦截。

## 方案对比

| 方案 | 实现 | 优点 | 缺点 | 选用 |
|------|------|------|------|-----|
| `SACLockScreenImmediate` | dlopen login.framework | 真正锁屏，无需辅助功能权限，ad-hoc 签名也有效 | 私有符号，理论上架审核风险（本项目自用，不上架） | **首选** |
| osascript Ctrl+Cmd+Q | 发送系统快捷键 | 公开方式 | 需辅助功能权限；ad-hoc 签名被 TCC 静默拦截 | 降级 |
| `pmset displaysleepnow` | 关闭显示器 | 不需私有 API | 受 screenLock delay 宽限期影响，可能锁不住 | 兜底 |
| `CGSession -suspend` | 切到登录窗口 | —— | 新版 macOS（Darwin 25）已移除该可执行文件 | 否 |
| IOKit `IOPMSleepSystem` | 整机睡眠 | —— | 整机睡眠太重，非"仅锁屏" | 否 |

## 选用方案的实现

真正锁屏（Swift dlopen 私有符号，无需辅助功能权限）：

```swift
typealias LockFn = @convention(c) () -> Int32
let h = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_NOW)
let sym = dlsym(h, "SACLockScreenImmediate")
let lock = unsafeBitCast(sym, to: LockFn.self)
_ = lock()  // 返回 0 即成功，屏幕立即锁到登录界面
```

降级息屏（Swift 调用子进程）：

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
