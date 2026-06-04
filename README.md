# NearLock

NearLock 是一个 macOS + Android 组合工具，用于解决「人离开工位却忘记锁屏」的问题。

Android 手机作为蓝牙信标（Beacon）持续广播，macOS 端扫描该信标并读取信号强度（RSSI）。当你带着手机离开 Mac、信号持续减弱到设定阈值以下时，macOS 自动锁屏，避免工位无人值守时屏幕长时间敞开。

## 工作原理

```
┌─────────────────┐         BLE 广播          ┌──────────────────┐
│  Android Beacon │  ───── Service UUID ────▶ │  macOS 菜单栏 App │
│   (Kotlin)      │                           │     (Swift)      │
└─────────────────┘                           └──────────────────┘
        │                                              │
   固定 UUID 广播                              扫描 / 读取 RSSI
   前台服务常驻                                RSSI 连续 N 秒 < 阈值
                                                      │
                                                      ▼
                                               自动锁屏 / 息屏
```

1. Android 端安装 NearLock Beacon App，通过 `BluetoothLeAdvertiser` 广播一个固定的 Service UUID。
2. macOS 端通过 `CoreBluetooth` 扫描该 UUID，绑定用户的 Android 手机，并持续读取 RSSI 信号强度。
3. 当 RSSI **连续 N 秒**低于用户设置的阈值时，判定为「用户带着手机离开了 Mac」，macOS 自动执行锁屏。

## 技术栈

### macOS 端

| 技术 | 用途 |
| --- | --- |
| Swift | 开发语言 |
| SwiftUI | 界面 |
| MenuBarExtra | 菜单栏常驻入口 |
| CoreBluetooth | BLE 扫描与 RSSI 读取 |
| UserDefaults | 配置持久化 |

### Android 端

| 技术 | 用途 |
| --- | --- |
| Kotlin | 开发语言 |
| Jetpack Compose | 界面 |
| BluetoothLeAdvertiser | BLE 广播 |
| Foreground Service | 保持广播常驻 |
| DataStore | 配置持久化 |

## 目录结构

```
NearLock/
├── macos/NearLock/                  # macOS 菜单栏 App（Swift / SwiftUI）
│   └── NearLock/
│       ├── NearLockApp.swift        # 入口，MenuBarExtra 组装依赖
│       ├── Bluetooth/               # 协议常量、CBCentralManager 扫描器
│       ├── Lock/                    # 息屏执行、接近度状态机与监控器
│       ├── Models/                  # 设备模型、事件日志
│       ├── Store/                   # UserDefaults 设置
│       └── Views/                   # 菜单栏内容视图
├── android/                         # Android Beacon App（Kotlin / Compose）
│   └── app/src/main/java/com/nearlock/beacon/
│       ├── ble/                     # 协议常量、deviceId 编码、广播控制器
│       ├── data/                    # DataStore 持久化 deviceId
│       ├── service/                 # 前台广播服务
│       └── ui/                      # MainActivity + Compose 界面 + ViewModel
├── .trellis/                        # Trellis 工作流、规范与任务（含 PRD、技术决策）
├── CONTRIBUTING.md                  # 开发规则（提交规范、语言规范）
└── README.md
```

固定 Service UUID 等双端共享约定分别硬编码在两端的 `NearLockProtocol`
（`android/.../ble/NearLockProtocol.kt` 与 `macos/.../Bluetooth/NearLockProtocol.swift`），
两端必须保持一致。

## MVP 功能

### macOS 端

1. 菜单栏常驻
2. 扫描 NearLock Beacon
3. 显示发现的 Android 设备
4. 支持绑定一个 Android 设备
5. 显示当前 RSSI
6. 设置 RSSI 阈值，默认 `-85 dBm`
7. 设置触发时间，默认 `15 秒`
8. 手机远离后自动锁屏
9. 支持暂停保护 10 / 30 / 60 分钟
10. 显示最近事件日志
11. 自动锁屏保护总开关（无限期启用/关闭，区别于定时暂停）
12. 立即锁屏按钮（手动点击即时息屏，不等检测）

### Android 端

1. 首次启动请求蓝牙相关权限
2. 生成唯一 `deviceId`
3. 点击按钮开启 BLE 广播
4. 使用固定 Service UUID
5. 前台服务保持广播
6. 显示当前广播状态
7. 支持停止广播

## 构建与运行

### Android

需要 Android Studio（或命令行 JDK 17 + Android SDK）。

```bash
cd android
./gradlew assembleDebug    # 产出 app/build/outputs/apk/debug/app-debug.apk
```

安装后：授予蓝牙权限 → 点击「开启广播」→ 前台通知常驻表示广播中。

> BLE 广播需真机，模拟器不支持；设备需支持外围广播
> （`isMultipleAdvertisementSupported == true`）。

### macOS

需要 Xcode 15+（已在 Xcode 26.5 验证 `xcodebuild` 构建通过）。

```bash
cd macos/NearLock
xcodebuild -scheme NearLock -configuration Debug build
# 或用 Xcode 打开 NearLock.xcodeproj 直接运行
```

运行后菜单栏出现锁形图标，首次运行请求蓝牙权限。

> **要达到真正锁屏效果**：在 **系统设置 → 锁定屏幕 → 屏幕关闭或睡眠后立即要求密码**
> 选择「立即」。NearLock 执行的是息屏（`pmset displaysleepnow`），由该系统设置决定是否同时锁定。
> macOS 工程默认**未开启 App Sandbox**（本地自用工具），以允许调用 `/usr/bin/pmset`。

## 联调步骤（需两台设备）

1. Android 真机安装并开启广播。
2. macOS 运行 NearLock，在「发现的设备」中看到该手机（deviceId 前 8 位 + RSSI）。
3. 点击「绑定」，面板切换为显示绑定设备的实时 RSSI 与离开计时。
4. 按需调整 RSSI 阈值与触发时间。
5. 带手机走远：RSSI 持续低于阈值或信号丢失，计时到达后 Mac 自动息屏锁屏。

> deviceId 显示差异：Android `UUID.toString()` 为小写，macOS 解码后显示大写，
> 二者指向同一 ID；macOS 内部比对统一用大写，不影响绑定。

## 开发约定

- 所有沟通、文档、代码注释、Git Commit Message 均使用**中文**。
- **每次逻辑改动完成后都要进行一次代码提交**，保持提交历史清晰、每个 commit 自洽。

详见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 开发路线

- [x] 搭建项目结构
- [x] Android BLE Beacon 广播
- [x] macOS 扫描与 RSSI 显示
- [x] macOS 自动锁屏逻辑

MVP 全部功能已实现。详细需求、技术决策与验收标准见
`.trellis/tasks/06-04-nearlock-mvp/`（PRD + research 决策文档）。
